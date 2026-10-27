function seconds(t, p) {
  split(t, p, ":")
  return p[1] * 3600 + p[2] * 60 + p[3]
}

function width(text, n, i, c, b, cp, w, total) {
  gsub(/\{[^}]*\}/, "", text)
  n = length(text)
  total = 0
  i = 1
  while (i <= n) {
    b = ord[substr(text, i, 1)]
    if (b < 128) { cp = b; i += 1 }
    else if (b >= 240) { cp = (b % 8) * 262144 + (ord[substr(text, i + 1, 1)] % 64) * 4096 + (ord[substr(text, i + 2, 1)] % 64) * 64 + ord[substr(text, i + 3, 1)] % 64; i += 4 }
    else if (b >= 224) { cp = (b % 16) * 4096 + (ord[substr(text, i + 1, 1)] % 64) * 64 + ord[substr(text, i + 2, 1)] % 64; i += 3 }
    else { cp = (b % 32) * 64 + ord[substr(text, i + 1, 1)] % 64; i += 2 }
    w = (cp in adv) ? adv[cp] : avg
    total += w
  }
  return total * fs / upm
}

function widest(text, parts, k, n, w, top) {
  gsub(/\\[Nn]/, "\n", text)
  n = split(text, parts, "\n")
  top = 0
  for (k = 1; k <= n; k++) { w = width(parts[k]); if (w > top) top = w }
  return top
}

function window_max(start, stop, key, i, best, hit, near, d, bestd) {
  best = -1
  for (i = 1; i <= samples; i++) {
    if (at[i] >= start && at[i] <= stop) { v = (key == "y" ? yh[i] : ed[i]); if (v > best) best = v; hit = 1 }
  }
  if (hit) return best
  bestd = -1
  for (i = 1; i <= samples; i++) {
    d = at[i] - (start + stop) / 2
    if (d < 0) d = -d
    if (bestd < 0 || d < bestd) { bestd = d; near = i }
  }
  if (near == "") return 0
  return (key == "y" ? yh[near] : ed[near])
}

function style_for(start, stop) {
  if (mode == "always") return "Box"
  if (mode == "never" || samples == 0) return "Outline"
  if (window_max(start, stop, "y") > yhigh_limit || window_max(start, stop, "e") > edge_limit) return "Box"
  return "Outline"
}

BEGIN {
  for (i = 1; i < 256; i++) ord[sprintf("%c", i)] = i
  avail = pw * 0.90
}

FNR == 1 { file++ }

file == 1 && $1 == "upm" { upm = $2; next }
file == 1 { adv[$1] = $2; sum += $2; count++; avg = sum / count; next }

file == 2 && /pts_time:/ { sub(/.*pts_time:/, ""); t = $1 + 0; next }
file == 2 && /lavfi\.signalstats\.YHIGH=/ { sub(/.*=/, ""); samples++; at[samples] = t; yh[samples] = $0 + 0; next }
file == 3 && /lavfi\.signalstats\.YAVG=/ { sub(/.*=/, ""); e++; ed[e] = $0 + 0; next }
file < 4 { next }

/^Dialogue:/ {
  head = $0
  text = $0
  for (k = 0; k < 9; k++) { p = index(text, ","); text = substr(text, p + 1) }
  head = substr(head, 1, length(head) - length(text))
  n = split(head, f, ",")
  start = seconds(f[2]) + offset
  stop = seconds(f[3]) + offset
  f[4] = style_for(start, stop)
  pad = (f[4] == "Box" ? 0.22 : 0.145) * fs * 2
  w = widest(text)
  scale = (w > 0) ? (avail - pad) / w : 1
  if (scale < 1) {
    if (scale < 0.8) scale = 0.8
    text = sprintf("{\\fscx%d\\fscy%d}", int(scale * 100), int(scale * 100)) text
  }
  out = f[1]
  for (k = 2; k < n; k++) out = out "," f[k]
  print out "," text
  next
}

{ print }
