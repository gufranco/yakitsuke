#!/bin/sh

# shellcheck source=SCRIPTDIR/state.sh
. "${YK_LIB:?}/state.sh"

yk_xml_escape() {
  printf '%s' "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'
}

yk_xml_document() {
  printf '%s\n' '<?xml version="1.0"?>'
  printf '%s\n' '<!DOCTYPE videocd PUBLIC "-//GNU//DTD VideoCD//EN" "http://www.gnu.org/software/vcdimager/videocd.dtd">'
  printf '%s\n' '<videocd xmlns="http://www.gnu.org/software/vcdimager/1.0/" class="vcd" version="2.0">'
  printf '  <info>\n    <album-id>%s</album-id>\n    <volume-count>%s</volume-count>\n' "$3" "$4"
  printf '    <volume-number>%s</volume-number>\n    <restriction>0</restriction>\n  </info>\n' "$5"
  printf '  <pvd>\n    <volume-id>%s</volume-id>\n    <system-id>CD-RTOS CD-BRIDGE</system-id>\n' "$2"
  printf '    <application-id/>\n    <preparer-id/>\n    <publisher-id/>\n  </pvd>\n'
  printf '  <sequence-items>\n    <sequence-item src="%s" id="sequence-00">\n' "$1"
  [ -z "$6" ] || printf '%s\n' "$6"
  printf '    </sequence-item>\n  </sequence-items>\n'
  printf '  <pbc>\n    <playlist id="lid-000">\n      <next ref="lid-end"/>\n      <return ref="lid-end"/>\n'
  printf '      <wait>5</wait>\n      <autowait>0</autowait>\n      <play-item ref="sequence-00"/>\n'
  printf '    </playlist>\n    <endlist id="lid-end" rejected="true"/>\n  </pbc>\n'
  printf '%s\n' '</videocd>'
}

yk_write_xml() {
  yk_wx_src="$(yk_xml_escape "$2")"
  yk_xml_document "${yk_wx_src}" "$3" "$4" "$5" "$6" "$7" >"$1"
}

yk_image_sectors() {
  yk_is_bytes="$(yk_file_bytes "$1")"
  printf '%s\n' "$((yk_is_bytes / 2352))"
}

yk_verify_image() {
  yk_vi_sectors="$(yk_image_sectors "$1")"
  if [ "${yk_vi_sectors}" -gt "${YK_CAPACITY}" ]; then
    yk_error "the image needs ${yk_vi_sectors} sectors and the media holds ${YK_CAPACITY}"
    return 1
  fi
  yk_info "  image ${yk_vi_sectors} of ${YK_CAPACITY} sectors, $((yk_vi_sectors * 100 / YK_CAPACITY))% full"
}

yk_build_image() {
  yk_bi_xml="${YK_WORK}/disc$1.xml"
  yk_bi_label="$(yk_iso_label "${YK_TITLE}_$1")"
  yk_bi_album="$(yk_iso_label "${YK_TITLE}")"
  yk_write_xml "${yk_bi_xml}" "$2" "${yk_bi_label}" "${yk_bi_album}" "${YK_TOTAL}" "$1" "$5"
  if ! vcdxbuild -c "$4" -b "$3" "${yk_bi_xml}" 2>"${YK_WORK}/vcdxbuild.log" >"${YK_WORK}/vcdxbuild.out"; then
    yk_error "vcdxbuild failed on disc $1"
    yk_detail "${YK_WORK}/vcdxbuild.log"
    return 2
  fi
  yk_verify_image "$3"
}
