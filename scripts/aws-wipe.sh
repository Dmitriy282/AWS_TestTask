#!/usr/bin/env bash
# Bring an AWS region to zero before the first `terraform apply`: everything created by hand or by the old
# Ansible ec2.yml — EC2 instances, Elastic IPs, unattached EBS volumes, key pairs, security groups
# (except `default`). After that the resources belong to Terraform: remove them with `terraform destroy`.
#
# It deletes EVERYTHING of these types in the region, not only this project — check the list first.
#   scripts/aws-wipe.sh            # only show what is there
#   scripts/aws-wipe.sh --delete   # show, ask for confirmation, delete
# Region: AWS_REGION (default us-east-1). Needs the AWS CLI v2 with credentials.
set -euo pipefail

REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"
DELETE=false
[ "${1:-}" = "--delete" ] && DELETE=true

ec2() { aws ec2 --region "$REGION" --output text "$@"; }

echo "Account $(aws sts get-caller-identity --query Account --output text), region $REGION"

echo; echo "== EC2 instances (not terminated)"
ec2 describe-instances --filters Name=instance-state-name,Values=pending,running,stopping,stopped \
    --query 'Reservations[].Instances[].[InstanceId,State.Name,InstanceType,PublicIpAddress,Tags[?Key==`Name`]|[0].Value]'
echo "== Elastic IPs"
ec2 describe-addresses --query 'Addresses[].[AllocationId,PublicIp,InstanceId]'
echo "== EBS volumes not attached to an instance"
ec2 describe-volumes --filters Name=status,Values=available --query 'Volumes[].[VolumeId,Size,CreateTime]'
echo "== Key pairs"
ec2 describe-key-pairs --query 'KeyPairs[].[KeyName,KeyPairId,CreateTime]'
echo "== Security groups (without default)"
ec2 describe-security-groups --query "SecurityGroups[?GroupName!='default'].[GroupId,GroupName,VpcId]"

if ! $DELETE; then
    echo; echo "Nothing deleted. To delete all of the above: $0 --delete"
    exit 0
fi

echo
read -r -p "Delete ALL of the above in $REGION? Type the region name to confirm: " answer
[ "$answer" = "$REGION" ] || { echo "Cancelled"; exit 1; }

# 1. Elastic IPs: an associated address must be disassociated before it can be released
ec2 describe-addresses --query 'Addresses[].[AllocationId,AssociationId]' | while read -r alloc assoc; do
    [ -n "$alloc" ] || continue
    if [ "$assoc" != "None" ]; then ec2 disassociate-address --association-id "$assoc"; fi
    echo "release $alloc"; ec2 release-address --allocation-id "$alloc"
done

# 2. Instances (their root volumes go with them: DeleteOnTermination)
instances=$(ec2 describe-instances --filters Name=instance-state-name,Values=pending,running,stopping,stopped \
    --query 'Reservations[].Instances[].InstanceId')
if [ -n "$instances" ]; then
    echo "terminate $instances"
    # shellcheck disable=SC2086
    ec2 terminate-instances --instance-ids $instances >/dev/null
    # shellcheck disable=SC2086
    ec2 wait instance-terminated --instance-ids $instances
fi

# 3. Volumes — read again: extra volumes of the terminated instances are free now
for vol in $(ec2 describe-volumes --filters Name=status,Values=available --query 'Volumes[].VolumeId'); do
    echo "delete $vol"; ec2 delete-volume --volume-id "$vol"
done

# 4. Key pairs
for key in $(ec2 describe-key-pairs --query 'KeyPairs[].KeyPairId'); do
    echo "delete key pair $key"; ec2 delete-key-pair --key-pair-id "$key"
done

# 5. Security groups. A group referenced by another group's rule cannot be deleted —
#    remove all their rules first, then the groups
sgs=$(ec2 describe-security-groups --query "SecurityGroups[?GroupName!='default'].GroupId")
for sg in $sgs; do
    ingress=$(ec2 describe-security-group-rules --filters Name=group-id,Values="$sg" --query 'SecurityGroupRules[?!IsEgress].SecurityGroupRuleId')
    egress=$(ec2 describe-security-group-rules --filters Name=group-id,Values="$sg" --query 'SecurityGroupRules[?IsEgress].SecurityGroupRuleId')
    # shellcheck disable=SC2086
    if [ -n "$ingress" ]; then ec2 revoke-security-group-ingress --group-id "$sg" --security-group-rule-ids $ingress >/dev/null; fi
    # shellcheck disable=SC2086
    if [ -n "$egress" ]; then ec2 revoke-security-group-egress --group-id "$sg" --security-group-rule-ids $egress >/dev/null; fi
done
for sg in $sgs; do
    echo "delete security group $sg"; ec2 delete-security-group --group-id "$sg"
done

echo; echo "Done. Left in $REGION:"
exec "$0"
