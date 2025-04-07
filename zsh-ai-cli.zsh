# default shortcut as Ctrl-o
(( ! ${+ZSH_AI_CLI_HOTKEY} )) && typeset -g ZSH_AI_CLI_HOTKEY='^o'
# default ollama model as llama3
(( ! ${+ZSH_AI_CLI_MODEL} )) && typeset -g ZSH_AI_CLI_MODEL='llama3'
# default response number as 5
(( ! ${+ZSH_AI_CLI_COMMANDS} )) && typeset -g ZSH_AI_CLI_COMMANDS='5'
# default ollama server host - support OLLAMA_HOST env var
typeset -g ZSH_AI_CLI_URL="${OLLAMA_HOST:-http://localhost:11434}"

test_ollama_connection() {
  print "🔍 Testing Ollama connection..."
  print "📡 Server URL: ${ZSH_AI_CLI_URL}"
  print "🤖 Model: ${ZSH_AI_CLI_MODEL}"
  
  local TEST_REQUEST='{
    "model": "'${ZSH_AI_CLI_MODEL}'",
    "messages": [
      {
        "role": "user",
        "content": "Say hello"
      }
    ],
    "stream": false
  }'
  
  print "\n📤 Sending test request..."
  print "$TEST_REQUEST"
  
  local TEST_RESPONSE=$(curl -s "${ZSH_AI_CLI_URL}/api/chat" \
    -H "Content-Type: application/json" \
    -d "$TEST_REQUEST")
  
  if [ $? -eq 0 ] && [ ! -z "$TEST_RESPONSE" ]; then
    print "\n📥 Received response:"
    print "$TEST_RESPONSE" | jq '.'
    print "\n✅ Ollama connection test successful!"
  else
    print "\n❌ Ollama connection test failed!"
    print "Response: $TEST_RESPONSE"
  fi
  print "----------------------------------------"
}

validate_required() {
  # check required tools are installed
  if (( ! $+commands[jq] )) then
      echo "🚨: zsh-ai-cli failed as jq NOT found!"
      echo "Please install it with 'brew install jq'"
      return 1;
  fi
  if (( ! $+commands[fzf] )) then
      echo "🚨: zsh-ai-cli failed as fzf NOT found!"
      echo "Please install it with 'brew install fzf'"
      return 1;
  fi
  if (( ! $+commands[curl] )) then
      echo "🚨: zsh-ai-cli failed as curl NOT found!"
      echo "Please install it with 'brew install curl'"
      return 1;
  fi
  
  # Check if Ollama server is accessible
  if ! curl -s "${ZSH_AI_CLI_URL}/api/tags" > /dev/null; then
    echo "🚨: zsh-ai-cli failed as Ollama server at ${ZSH_AI_CLI_URL} is not accessible!"
    return 1;
  fi
  
  # Check if model exists
  if ! curl -s "${ZSH_AI_CLI_URL}/api/tags" | grep -q $ZSH_AI_CLI_MODEL; then
    echo "🚨: zsh-ai-cli failed as model ${ZSH_AI_CLI_MODEL} not found on server!"
    echo "Please pull it with 'ollama pull ${ZSH_AI_CLI_MODEL}' or adjust ZSH_AI_CLI_MODEL"
    return 1;
  fi
  
  # Run connection test
  # test_ollama_connection
}

check_status() {
  tput cuu 1 # cleanup waiting message
  if [ $? -ne 0 ]; then
    echo "༼ つ ◕_◕ ༽つ Sorry! Please try again..."
    exit 1
  fi
}

fzf_ollama_commands() {
  setopt extendedglob
  validate_required
  if [ $? -eq 1 ]; then
    return 1
  fi

  ZSH_AI_CLI_USER_QUERY=$BUFFER

  zle end-of-line
  zle reset-prompt

  print
  print -u1 "👻Please wait..."

  ZSH_AI_CLI_MESSAGE_CONTENT="Generate a single Unix/Linux command for this task without any explanation: $ZSH_AI_CLI_USER_QUERY"

  ZSH_AI_CLI_REQUEST_BODY='{
    "model": "'$ZSH_AI_CLI_MODEL'",
    "prompt": "'$ZSH_AI_CLI_MESSAGE_CONTENT'",
    "stream": false
  }'

  ZSH_AI_CLI_RESPONSE=$(curl --silent "${ZSH_AI_CLI_URL}/api/generate" \
    -H "Content-Type: application/json" \
    -d "$ZSH_AI_CLI_REQUEST_BODY")
  local ret=$?

  # Extract just the command from the response
  ZSH_AI_CLI_RESULT=$(echo "$ZSH_AI_CLI_RESPONSE" | tr -d '\0' | jq -r '.response' | grep -m1 '`.*`' | sed 's/`\(.*\)`/\1/')
  
  # If no command found in backticks, try to extract the first line that looks like a command
  if [ -z "$ZSH_AI_CLI_RESULT" ]; then
    ZSH_AI_CLI_RESULT=$(echo "$ZSH_AI_CLI_RESPONSE" | tr -d '\0' | jq -r '.response' | grep -m1 '^[a-zA-Z].*')
  fi
  
  # Cleanup any remaining markdown or explanation text
  ZSH_AI_CLI_RESULT=$(echo "$ZSH_AI_CLI_RESULT" | sed 's/^# //' | sed 's/^\$ //' | sed 's/^> //')
  
  if [ $? -eq 0 ] && [ ! -z "$ZSH_AI_CLI_RESULT" ]; then
    tput cuu 1 # cleanup waiting message
    BUFFER="$ZSH_AI_CLI_RESULT"
  else
    tput cuu 1 # cleanup waiting message
    print "❌ Failed to get command suggestion"
    BUFFER="$ZSH_AI_CLI_USER_QUERY"
  fi

  zle end-of-line
  zle reset-prompt
  return $ret
}

validate_required

autoload fzf_ollama_commands
zle -N fzf_ollama_commands

bindkey $ZSH_AI_CLI_HOTKEY fzf_ollama_commands
