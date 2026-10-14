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
