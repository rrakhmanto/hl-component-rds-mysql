CloudFormation do

  Description "#{component_name} - #{component_version}"

  az_conditions_resources('SubnetPersistence', maximum_availability_zones)

  tags = []
  tags << { Key: 'Environment', Value: Ref(:EnvironmentName) }
  tags << { Key: 'EnvironmentType', Value: Ref(:EnvironmentType) }

  extra_tags.each { |key,value| tags << { Key: key, Value: value } } if defined? extra_tags

  EC2_SecurityGroup "SecurityGroupRDS" do
    VpcId Ref('VPCId')
    GroupDescription FnJoin(' ', [ Ref(:EnvironmentName), component_name, 'security group' ])
    Tags tags + [{ Key: 'Name', Value: FnJoin('-', [ Ref(:EnvironmentName), component_name, 'security-group' ])}]
  end

  EC2_SecurityGroupIngress('ECSIngressRule') do
    Description 'Ephemeral port range for ECS'
    IpProtocol 'tcp'
    FromPort '3306'
    ToPort '3306'
    GroupId FnGetAtt('SecurityGroupRDS','GroupId')
    SourceSecurityGroupId Ref('EcsSecurityGroup')
  end

  RDS_DBSubnetGroup 'SubnetGroupRDS' do
    DBSubnetGroupDescription FnJoin(' ', [ Ref(:EnvironmentName), component_name, 'subnet group' ])
    SubnetIds az_conditional_resources('SubnetPersistence', maximum_availability_zones)
    Tags tags + [{ Key: 'Name', Value: FnJoin('-', [ Ref(:EnvironmentName), component_name, 'subnet-group' ])}]
  end

  RDS_DBParameterGroup 'ParametersRDS' do
    Description FnJoin(' ', [ Ref(:EnvironmentName), component_name, 'parameter group' ])
    Family family
    Parameters parameters if defined? parameters
    Tags tags + [{ Key: 'Name', Value: FnJoin('-', [ Ref(:EnvironmentName), component_name, 'parameter-group' ])}]
  end

  RDS_DBInstance 'RDS' do
    DeletionPolicy deletion_policy if defined? deletion_policy
    DBInstanceClass Ref('RDSInstanceType')
    AllocatedStorage Ref('RDSAllocatedStorage')
    StorageType 'gp2'
    Engine 'mysql'
    EngineVersion engine_version
    DBParameterGroupName Ref('ParametersRDS')
    MasterUsername  master_username if defined? master_username
    MasterUserPassword master_password if defined? master_password
    DBSnapshotIdentifier  Ref('RDSSnapshotID')
    DBSubnetGroupName  Ref('SubnetGroupRDS')
    VPCSecurityGroups [Ref('SecurityGroupRDS')]
    MultiAZ Ref('MultiAZ')
    Tags  tags + [
      { Key: 'Name', Value: FnJoin('-', [ Ref(:EnvironmentName), component_name, 'instance' ])},
      { Key: 'SnapshotID', Value: Ref('RDSSnapshotID')},
      { Key: 'Version', Value: family}
    ]
  end

  record = defined?(dns_record) ? dns_record : 'mysql'

  Route53_RecordSet('DatabaseIntHostRecord') do
    HostedZoneName FnJoin('', [ Ref('EnvironmentName'), '.', Ref('DnsDomain'), '.'])
    Name FnJoin('', [ record, '.', Ref('EnvironmentName'), '.', Ref('DnsDomain'), '.' ])
    Type 'CNAME'
    TTL 60
    ResourceRecords [ FnGetAtt('RDS','Endpoint.Address') ]
  end

end
