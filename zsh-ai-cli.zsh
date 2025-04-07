# default shortcut as Ctrl-o
(( ! ${+ZSH_AI_CLI_HOTKEY} )) && typeset -g ZSH_AI_CLI_HOTKEY='^o'
# default ollama model as llama3
(( ! ${+ZSH_AI_CLI_MODEL} )) && typeset -g ZSH_AI_CLI_MODEL='llama3'
# default response number as 5
(( ! ${+ZSH_AI_CLI_COMMANDS} )) && typeset -g ZSH_AI_CLI_COMMANDS='5'
# default ollama server host - support OLLAMA_HOST env var
typeset -g ZSH_AI_CLI_URL="${OLLAMA_HOST:-http://localhost:11434}"

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

  ZSH_AI_CLI_MESSAGE_CONTENT="Seeking OLLAMA for MacOS terminal commands for the following task: $ZSH_AI_CLI_USER_QUERY. Reply with an array without newlines consisting solely of possible commands. The format would be like: ['command1; comand2;', 'command3&comand4;']. Response only contains array, no any additional description. No additional text should be present in each entry and commands, remove empty string entry. Each string entry should be a new string entry. If the task need more than one command, combine them in one string entry. Each string entry should only contain the command(s). Do not include empty entry. Provide multiple entry (at most $ZSH_AI_CLI_COMMANDS relevant entry) in response Json suggestions if available. Please ensure response can be parsed by jq"

  ZSH_AI_CLI_REQUEST_BODY='{
    "model": "'$ZSH_AI_CLI_MODEL'",
    "messages": [
      {
        "role": "user",
        "content":  "'$ZSH_AI_CLI_MESSAGE_CONTENT'"
      }
    ],
    "stream": false
  }'

  ZSH_AI_CLI_RESPONSE=$(curl --silent "${ZSH_AI_CLI_URL}/api/chat" \
    -H "Content-Type: application/json" \
    -d "$ZSH_AI_CLI_REQUEST_BODY")
  local ret=$?

  # trim response content newline
  ZSH_AI_CLI_SUGGESTION=$(echo $ZSH_AI_CLI_RESPONSE | tr -d '\n\r' | tr -d '\0' | jq '.')
  check_status

  # collect suggestion commands from response content
  ZSH_AI_CLI_SUGGESTION=$(echo "$ZSH_AI_CLI_RESPONSE" | tr -d '\0' | jq -r '.message.content')
  check_status

  # attempts to extract suggestions from ZSH_OLLAMA_COMMANDS_SUGGESTION using jq.
  # If jq fails or returns no output, displays an error message and exits.
  # Otherwise, pipes the output to fzf for interactive selection
  ZSH_AI_CLI_SELECTED=$(echo $ZSH_AI_CLI_SUGGESTION | tr -d '\0' | jq -r '.[]')
  check_status

  tput cuu 1 # cleanup waiting message

  ZSH_AI_CLI_SELECTED=$(echo $ZSH_AI_CLI_SUGGESTION | jq -r '.[]' | fzf --ansi --height=~10 --cycle)
  BUFFER=$ZSH_AI_CLI_SELECTED

  zle end-of-line
  zle reset-prompt
  return $ret
}

validate_required

autoload fzf_ollama_commands
zle -N fzf_ollama_commands

bindkey $ZSH_AI_CLI_HOTKEY fzf_ollama_commands
