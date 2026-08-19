// =============================================================================
// Omarchy File Picker - Model and Search Logic
// =============================================================================

function formatSize(bytes) {
  var b = Number(bytes) || 0
  if (b < 1024) return b + " B"
  if (b < 1024 * 1024) return (b / 1024).toFixed(1) + " KB"
  if (b < 1024 * 1024 * 1024) return (b / (1024 * 1024)).toFixed(1) + " MB"
  return (b / (1024 * 1024 * 1024)).toFixed(2) + " GB"
}

function formatDate(timestamp) {
  var ts = Number(timestamp)
  if (!ts || isNaN(ts)) return ""
  var date = new Date(ts * 1000)
  var year = date.getFullYear()
  var month = ("0" + (date.getMonth() + 1)).slice(-2)
  var day = ("0" + date.getDate()).slice(-2)
  var hours = ("0" + date.getHours()).slice(-2)
  var mins = ("0" + date.getMinutes()).slice(-2)
  return year + "-" + month + "-" + day + " " + hours + ":" + mins
}

function iconForFile(category, ext) {
  var e = String(ext || "").toLowerCase()
  var c = String(category || "").toLowerCase()

  if (e === "pdf") return "󰈦"
  if (e === "md" || e === "markdown") return ""
  if (c === "documents") return "󰈙"
  if (c === "notes") return "󰎞"
  if (c === "videos") return "󰕼"
  if (c === "audio") return "󰎆"
  if (c === "images") return "󰈟"
  if (c === "code") return "󰈮"
  return "󰈔"
}

function parseTsv(raw) {
  var text = String(raw || "").trim()
  if (!text) return []
  var lines = text.split("\n")
  var results = []

  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim()
    if (!line) continue
    var parts = line.split("\t")
    if (parts.length < 5) continue

    var fullPath = parts[0]
    var cat = parts[1]
    var ext = parts[2]
    var size = Number(parts[3]) || 0
    var mtime = Number(parts[4]) || 0

    var lastSlash = fullPath.lastIndexOf("/")
    var name = lastSlash >= 0 ? fullPath.slice(lastSlash + 1) : fullPath
    var dir = lastSlash >= 0 ? fullPath.slice(0, lastSlash) : ""

    results.push({
      path: fullPath,
      name: name,
      dir: dir,
      category: cat,
      extension: ext,
      size: size,
      sizeFormatted: formatSize(size),
      mtime: mtime,
      mtimeFormatted: formatDate(mtime),
      icon: iconForFile(cat, ext)
    })
  }

  return results
}

function fuzzyScore(pattern, text) {
  var pLen = pattern.length
  var tLen = text.length
  if (pLen === 0) return 100
  if (pLen > tLen) return -1

  var pLower = pattern.toLowerCase()
  var tLower = text.toLowerCase()

  var exactIdx = tLower.indexOf(pLower)
  if (exactIdx === 0) return 1000 - tLen
  if (exactIdx > 0) return 500 - exactIdx - tLen

  var pIdx = 0
  var score = 0
  var prevMatchIdx = -1

  for (var tIdx = 0; tIdx < tLen && pIdx < pLen; tIdx++) {
    if (tLower.charAt(tIdx) === pLower.charAt(pIdx)) {
      if (prevMatchIdx === tIdx - 1) score += 20 // Consecutive bonus
      if (tIdx === 0 || tLower.charAt(tIdx - 1) === " " || tLower.charAt(tIdx - 1) === "_" || tLower.charAt(tIdx - 1) === "-") {
        score += 30 // Word boundary bonus
      }
      prevMatchIdx = tIdx
      pIdx++
    }
  }

  return pIdx === pLen ? score : -1
}

function filterFiles(files, query, selectedCategory, limit) {
  var maxItems = limit || 500
  if (!Array.isArray(files) || files.length === 0) return []

  var q = String(query || "").trim()
  var cat = String(selectedCategory || "all").toLowerCase()
  var candidates = []

  for (var i = 0; i < files.length; i++) {
    var item = files[i]

    if (cat !== "all" && item.category !== cat) {
      continue
    }

    if (!q) {
      candidates.push({ item: item, score: 0 })
      if (candidates.length >= maxItems) break
      continue
    }

    var nameScore = fuzzyScore(q, item.name)
    var pathScore = fuzzyScore(q, item.path)

    var bestScore = -1
    if (nameScore >= 0) bestScore = nameScore + 200
    else if (pathScore >= 0) bestScore = pathScore

    if (bestScore >= 0) {
      candidates.push({ item: item, score: bestScore })
    }
  }

  if (q) {
    candidates.sort(function(a, b) {
      return b.score - a.score
    })
  }

  var out = []
  var count = Math.min(candidates.length, maxItems)
  for (var j = 0; j < count; j++) {
    out.push(candidates[j].item)
  }

  return out
}
