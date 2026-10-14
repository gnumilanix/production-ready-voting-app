import "module" "common" {
  source = "../../modules/common/common.sentinel"
}

mock "tfplan/v2" {
  module {
    source = "../../testdata/mock-pass.sentinel"
  }
}

test {
  rules = {
    main = true
  }
}
