# Silica Terminal shell integration (bash and zsh): tells the terminal where the shell is
# (OSC 7) and where prompts, commands and their output begin and end (OSC 133), for new tabs in
# the same directory, jump to the previous or next prompt, Select Between Marks and the
# warning before closing a window that runs a command. Installed as /etc/profile.d/
# silica-terminal.sh by the package; it does nothing outside Silica Terminal.

# Only in Silica Terminal, only in interactive shells, only once.
[ -n "${SILICA_TERMINAL:-}" ] || return 0 2>/dev/null || exit 0
case $- in *i*) ;; *) return 0 2>/dev/null || exit 0 ;; esac
[ -z "${__silica_integration:-}" ] || return 0 2>/dev/null || exit 0
__silica_integration=1

if [ -n "${BASH_VERSION:-}" ]; then
  __silica_urlencode() {
    local LC_ALL=C s=$1 out= c i
    for ((i = 0; i < ${#s}; i++)); do
      c=${s:i:1}
      case $c in
        [a-zA-Z0-9/._~-]) out+=$c ;;
        *) printf -v c '%%%02X' "'$c"; out+=$c ;;
      esac
    done
    printf '%s' "$out"
  }
  __silica_prompt() {
    local status=$?
    # The command that just ran finished with this status, then the new directory.
    printf '\e]133;D;%d\a\e]7;file://%s%s\a' "$status" "${HOSTNAME:-localhost}" "$(__silica_urlencode "$PWD")"
    return "$status"
  }
  PROMPT_COMMAND="__silica_prompt${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
  # A starts the prompt, B ends it; C (PS0, bash 4.4) marks the start of the command's output.
  PS1='\[\e]133;A\a\]'"$PS1"'\[\e]133;B\a\]'
  PS0=$'\e]133;C\a'"${PS0:-}"
elif [ -n "${ZSH_VERSION:-}" ]; then
  autoload -Uz add-zsh-hook
  __silica_urlencode() {
    local LC_ALL=C s=$1 out= c i
    for ((i = 1; i <= ${#s}; i++)); do
      c=${s[i]}
      case $c in
        [a-zA-Z0-9/._~-]) out+=$c ;;
        *) out+=$(printf '%%%02X' "'$c") ;;
      esac
    done
    printf '%s' "$out"
  }
  __silica_precmd() {
    local status=$?
    printf '\e]133;D;%d\a\e]7;file://%s%s\a' "$status" "${HOST:-localhost}" "$(__silica_urlencode "$PWD")"
  }
  __silica_preexec() { printf '\e]133;C\a'; }
  add-zsh-hook precmd __silica_precmd
  add-zsh-hook preexec __silica_preexec
  PS1=$'%{\e]133;A\a%}'"$PS1"$'%{\e]133;B\a%}'
fi
