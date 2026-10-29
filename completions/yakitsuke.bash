# shellcheck shell=bash
# shellcheck disable=SC2207

_yakitsuke() {
  local cur prev words options
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD - 1]}"
  options="--cd74 --cd80 --cd90 --disc-minutes --overlap --scene-snap --title --chapters --ntsc --pal --film --letterbox --crop --borders --deinterlace --denoise --sharpen --no-sharpen --no-color-convert --audio-track --normalize --sub-track --sub-color --sub-box --sub-offset --sub-style --encoder --output-dir --keep-mpeg --force --resume --preview --dry-run --json"

  case "${prev}" in
  --borders) words="auto off" ;;
  --deinterlace) words="auto on ivtc off" ;;
  --sub-color) words="auto white yellow" ;;
  --sub-box) words="auto always never" ;;
  --encoder) words="auto mpeg2enc ffmpeg" ;;
  --output-dir)
    COMPREPLY=($(compgen -d -- "${cur}"))
    return
    ;;
  --disc-minutes | --overlap | --scene-snap | --title | --chapters | --denoise | --audio-track | --sub-track | --sub-offset | --sub-style | --preview)
    COMPREPLY=()
    return
    ;;
  *) words="" ;;
  esac
  if [[ -n "${words}" ]]; then
    COMPREPLY=($(compgen -W "${words}" -- "${cur}"))
    return
  fi
  if [[ "${cur}" == -* ]]; then
    COMPREPLY=($(compgen -W "${options}" -- "${cur}"))
    return
  fi
  words="$(compgen -f -- "${cur}" || true)"
  if [[ "${COMP_CWORD}" -eq 1 ]]; then
    words="doctor version help ${words}"
  fi
  COMPREPLY=($(compgen -W "${words}" -- "${cur}"))
}

complete -F _yakitsuke yakitsuke
