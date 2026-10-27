/Repeated Fields/ { repeated = $0 }
/Multi frame detection/ { multi = $0 }
END {
  n = split(repeated, r, /[ \t]+/)
  for (i = 1; i <= n; i++) {
    if (r[i] == "Neither:") neither = r[i + 1] + 0
    if (r[i] == "Top:") top = r[i + 1] + 0
    if (r[i] == "Bottom:") bottom = r[i + 1] + 0
  }
  n = split(multi, m, /[ \t]+/)
  for (i = 1; i <= n; i++) {
    if (m[i] == "TFF:") tff = m[i + 1] + 0
    if (m[i] == "BFF:") bff = m[i + 1] + 0
    if (m[i] == "Progressive:") prog = m[i + 1] + 0
  }
  sampled = tff + bff + prog
  if (sampled < 50) { print "off"; exit }
  repeats = top + bottom
  frames = neither + repeats
  if (frames > 0 && repeats / frames > 0.25) { print "ivtc"; exit }
  dominant = (tff > bff) ? tff : bff
  weak = (tff > bff) ? bff : tff
  if (dominant > prog && dominant > weak * 3) { print "on"; exit }
  print "off"
}
