import "module" "common" {
  source = "../../modules/common/common.sentinel"
}

mock "tfplan/v2" {
  module {
    source = "../../testdata/mock-jumpbox-ingress-fail.sentinel"
  }
}

test {
  rules = {
    main = false
  }
}
