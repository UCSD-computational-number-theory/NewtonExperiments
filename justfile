# Execute Julia code via REPLicant
julia code:
    printf '%s' "{{code}}" | nc -N localhost $(cat REPLICANT_PORT)

# Documentation lookup
docs binding:
    just julia "@doc {{binding}}"

# Run all tests
test-all:
    just julia "@run_package_tests"

# Run specific test item
test-item item:
    just julia "@run_package_tests filter=ti->ti.name == String(:{{item}})"
