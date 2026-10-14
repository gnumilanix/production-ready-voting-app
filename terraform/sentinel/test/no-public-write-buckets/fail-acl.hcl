import "module" "common" {
  source = "../../modules/common/common.sentinel"
}

mock "tfplan/v2" {
  module {
    source = "../../testdata/mock-public-bucket-acl-fail.sentinel"
  }
}

test {
  rules = {
    main = false
  }
}
