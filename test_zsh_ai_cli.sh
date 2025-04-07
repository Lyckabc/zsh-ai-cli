#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TOTAL_TESTS=0
PASSED_TESTS=0

print_header() {
    echo -e "\n${YELLOW}=== $1 ===${NC}\n"
}

print_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ $2${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}✗ $2${NC}"
        echo -e "${RED}Error: $3${NC}"
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

# Test 1: Check if required tools are installed
test_required_tools() {
    print_header "Testing Required Tools"
    
    # Test jq
    if command -v jq >/dev/null 2>&1; then
        print_result 0 "jq is installed"
    else
        print_result 1 "jq is installed" "jq not found"
    fi
    
    # Test fzf
    if command -v fzf >/dev/null 2>&1; then
        print_result 0 "fzf is installed"
    else
        print_result 1 "fzf is installed" "fzf not found"
    fi
    
    # Test curl
    if command -v curl >/dev/null 2>&1; then
        print_result 0 "curl is installed"
    else
        print_result 1 "curl is installed" "curl not found"
    fi
}

# Test 2: Check Ollama server connection
test_ollama_server() {
    print_header "Testing Ollama Server Connection"
    
    # Test if OLLAMA_HOST is set
    if [ ! -z "${OLLAMA_HOST}" ]; then
        print_result 0 "OLLAMA_HOST is set" "Value: ${OLLAMA_HOST}"
    else
        print_result 1 "OLLAMA_HOST is set" "OLLAMA_HOST environment variable not set"
    fi
    
    # Test server connection
    if curl -s "${OLLAMA_HOST}/api/tags" > /dev/null; then
        print_result 0 "Ollama server is accessible"
    else
        print_result 1 "Ollama server is accessible" "Could not connect to ${OLLAMA_HOST}"
    fi
}

# Test 3: Test model availability
test_model_availability() {
    print_header "Testing Model Availability"
    
    # Get available models
    MODELS=$(curl -s "${OLLAMA_HOST}/api/tags" | jq -r '.models[].name')
    
    if [ ! -z "$MODELS" ]; then
        print_result 0 "Models list retrieved" "Available models: ${MODELS}"
    else
        print_result 1 "Models list retrieved" "Could not get models list"
    fi
}

# Test 4: Test command generation
test_command_generation() {
    print_header "Testing Command Generation"
    
    # Test cases
    TEST_CASES=(
        "list files"
        "find text files"
        "show system info"
    )
    
    for query in "${TEST_CASES[@]}"; do
        echo -e "\nTesting query: '${query}'"
        
        RESPONSE=$(curl -s "${OLLAMA_HOST}/api/generate" \
            -H "Content-Type: application/json" \
            -d '{
                "model": "llama3.1:8b",
                "prompt": "Generate a single Unix/Linux command for this task without any explanation: '"${query}"'",
                "stream": false
            }')
        
        COMMAND=$(echo "$RESPONSE" | jq -r '.response' | grep -m1 '`.*`' | sed 's/`\(.*\)`/\1/')
        
        if [ ! -z "$COMMAND" ]; then
            print_result 0 "Generated command for '${query}'" "Command: ${COMMAND}"
        else
            print_result 1 "Generated command for '${query}'" "No command generated"
        fi
    done
}

# Run all tests
main() {
    echo -e "${YELLOW}Starting zsh-ai-cli tests...${NC}"
    
    test_required_tools
    test_ollama_server
    test_model_availability
    test_command_generation
    
    # Print summary
    echo -e "\n${YELLOW}=== Test Summary ===${NC}"
    echo -e "Total tests: ${TOTAL_TESTS}"
    echo -e "Passed tests: ${GREEN}${PASSED_TESTS}${NC}"
    echo -e "Failed tests: ${RED}$((TOTAL_TESTS - PASSED_TESTS))${NC}"
    
    # Return exit code based on test results
    if [ ${PASSED_TESTS} -eq ${TOTAL_TESTS} ]; then
        echo -e "\n${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "\n${RED}Some tests failed!${NC}"
        exit 1
    fi
}

# Run the tests
main 