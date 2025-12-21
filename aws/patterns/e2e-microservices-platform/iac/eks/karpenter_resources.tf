resource "kubectl_manifest" "karpenter_node_class" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1
    kind: EC2NodeClass
    metadata:
      name: default
    spec:
      amiFamily: AL2023
      role: ${module.eks_blueprints_addons.karpenter.node_iam_role_name}
      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${local.name}
      securityGroupSelectorTerms:
        - tags:
            kubernetes.io/cluster/${local.name}: "*"
  YAML

  depends_on = [module.eks_blueprints_addons]
}

resource "kubectl_manifest" "karpenter_node_pool" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      name: default
    spec:
      template:
        spec:
          nodeClassRef:
            group: karpenter.k8s.aws
            kind: EC2NodeClass
            name: default
          requirements:
            - key: "karpenter.sh/capacity-type"
              operator: In
              values: ["on-demand", "spot"]
            - key: "kubernetes.io/arch"
              operator: In
              values: ["amd64"]
  YAML

  depends_on = [kubectl_manifest.karpenter_node_class]
}