mock "tfplan/v2" {
  module {
    source = "../../testdata/mock-fail.sentinel"
  }
}

test {
  rules = {
    main = false
  }
}
