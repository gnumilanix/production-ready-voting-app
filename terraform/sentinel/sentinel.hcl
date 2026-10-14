# Sentinel policy set for the voting app infrastructure.
# Evaluated in CI against `terraform show -json` output. The workflow generates
# mock-tfplan.sentinel from the plan JSON before running `sentinel apply`.

mock "tfplan/v2" {
  module {
    source = "./mock-tfplan.sentinel"
  }
}

policy "allowed-instance-sizes" {
  source            = "./allowed-instance-sizes.sentinel"
  enforcement_level = "hard-mandatory"
}

policy "no-public-write-buckets" {
  source            = "./no-public-write-buckets.sentinel"
  enforcement_level = "hard-mandatory"
}

policy "restrict-ingress-cidr" {
  source            = "./restrict-ingress-cidr.sentinel"
  enforcement_level = "hard-mandatory"
}

policy "eks-min-version" {
  source            = "./eks-min-version.sentinel"
  enforcement_level = "hard-mandatory"
}

policy "eks-no-public-endpoint" {
  source            = "./eks-no-public-endpoint.sentinel"
  enforcement_level = "hard-mandatory"
}

policy "enforce-region" {
  source            = "./enforce-region.sentinel"
  enforcement_level = "hard-mandatory"
}

policy "nodegroup-max-size" {
  source            = "./nodegroup-max-size.sentinel"
  enforcement_level = "hard-mandatory"
}
