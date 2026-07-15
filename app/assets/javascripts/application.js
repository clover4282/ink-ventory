const words = (text) => text.normalize("NFC").toLocaleLowerCase("ko").match(/[\p{L}]+|[\p{N}]+/gu) || []

const distance = (left, right) => {
  let previous = Array.from({ length: right.length + 1 }, (_, index) => index)
  left.forEach((leftCharacter, leftIndex) => {
    const current = [leftIndex + 1]
    right.forEach((rightCharacter, rightIndex) => {
      current.push(Math.min(current[rightIndex] + 1, previous[rightIndex + 1] + 1, previous[rightIndex] + (leftCharacter === rightCharacter ? 0 : 1)))
    })
    previous = current
  })
  return previous.at(-1)
}

const similar = (term, candidate) => {
  const left = [...term.normalize("NFD")]
  const right = [...candidate.normalize("NFD")]
  const limit = left.length >= 6 ? 2 : left.length >= 3 ? 1 : 0
  return Math.abs(left.length - right.length) <= limit && distance(left, right) <= limit
}

const highlight = (element, terms) => {
  const title = element.dataset.productTitle
  const fragment = document.createDocumentFragment()
  let position = 0

  title.matchAll(/[\p{L}]+|[\p{N}]+/gu).forEach((match) => {
    fragment.append(title.slice(position, match.index))
    const word = match[0].normalize("NFC").toLocaleLowerCase("ko")
    const matched = terms.some((term) => word.includes(term))
    const node = matched ? document.createElement("mark") : document.createTextNode(match[0])
    if (matched) node.textContent = match[0]
    fragment.append(node)
    position = match.index + match[0].length
  })

  fragment.append(title.slice(position))
  element.replaceChildren(fragment)
}

const score = (text, query, terms, candidates) => {
  let value = text.includes(query.toLocaleLowerCase("ko")) ? 100 : 0

  for (const term of terms) {
    if (text.includes(term)) value += 10
    else if (candidates.some((candidate) => similar(term, candidate))) value += 1
    else return 0
  }
  return value
}

const catalogFilters = () => {
  const controls = document.querySelector("[data-catalog-controls]")
  const numberValue = (selector) => {
    const value = controls.querySelector(selector).value
    return value === "" ? null : Number(value)
  }

  return {
    site: controls.querySelector("[data-filter-site]").value,
    status: controls.querySelector("[data-filter-status]").value,
    minPrice: numberValue("[data-filter-min-price]"),
    maxPrice: numberValue("[data-filter-max-price]"),
    restocked: controls.querySelector("[data-filter-restocked]").checked,
    sort: controls.querySelector("[data-catalog-sort]").value
  }
}

const matchesFilters = (card, filters) => {
  const price = card.dataset.price === "" ? null : Number(card.dataset.price)
  if (filters.site && card.dataset.siteId !== filters.site) return false
  if (filters.status && card.dataset.status !== filters.status) return false
  if (filters.minPrice !== null && (price === null || price < filters.minPrice)) return false
  if (filters.maxPrice !== null && (price === null || price > filters.maxPrice)) return false
  return !filters.restocked || Number(card.dataset.restockedAt) > 0
}

const sortCatalog = (ranked, sort) => {
  const metric = (entry, name) => Number(entry.card.dataset[name] || 0)
  const price = (entry, missing) => entry.card.dataset.price === "" ? missing : Number(entry.card.dataset.price)

  ranked.sort((left, right) => {
    let order = 0
    if (sort === "popularity") order = metric(right, "clicks") - metric(left, "clicks")
    else if (sort === "newest") order = metric(right, "createdAt") - metric(left, "createdAt")
    else if (sort === "likes") order = metric(right, "likes") - metric(left, "likes")
    else if (sort === "price_asc") order = price(left, Infinity) - price(right, Infinity)
    else if (sort === "price_desc") order = price(right, -1) - price(left, -1)
    else if (sort === "restocked") order = metric(right, "restockedAt") - metric(left, "restockedAt")
    else order = right.matchScore - left.matchScore

    return order || right.matchScore - left.matchScore || left.index - right.index
  })
}

const search = (form) => {
  const input = form.querySelector("input[name='q']")
  const query = input.value.normalize("NFC").trim()
  const terms = words(query)
  const filters = catalogFilters()
  const cards = [...document.querySelectorAll("[data-catalog-card]")]
  const ranked = []

  cards.forEach((card, index) => {
    const text = card.dataset.searchText
    const candidates = card.searchWords ||= words(text)
    const matchScore = terms.length ? score(text, query, terms, candidates) : 1
    card.catalogIndex ??= index
    card.hidden = true
    const title = card.querySelector("[data-product-title]")
    if (title.querySelector("mark")) highlight(title, [])
    if (matchScore > 0 && matchesFilters(card, filters)) ranked.push({ card, matchScore, index: card.catalogIndex })
  })

  sortCatalog(ranked, filters.sort)
  ranked.slice(0, 50).forEach(({ card }) => {
    document.querySelector("[data-catalog-cards]").append(card)
    card.hidden = false
    highlight(card.querySelector("[data-product-title]"), terms)
  })
  const count = ranked.length

  document.querySelector("[data-catalog-title]").textContent = query ? `검색 결과 ${count}개` : `현재 수집 만년필 ${count}개`
  const filtered = filters.site || filters.status || filters.minPrice !== null || filters.maxPrice !== null || filters.restocked || filters.sort !== "relevance"
  const summary = [query && `“${query}”`, filtered && "필터·정렬 적용"].filter(Boolean).join(" · ")
  document.querySelector("[data-catalog-summary]").textContent = summary ? `${summary} · ` : "최근 정상 확인순 최대 50개"
  document.querySelector("[data-catalog-clear]").hidden = !query && !filtered
  document.querySelector("[data-catalog-empty]").hidden = count > 0
  document.querySelector("[data-catalog-empty]").textContent = query ? "검색 결과가 없습니다." : "아직 정상 수집된 상품이 없습니다."
  document.querySelector("[data-catalog-cards]").hidden = count === 0

  const url = new URL(form.action, window.location.href)
  query ? url.searchParams.set("q", query) : url.searchParams.delete("q")
  history.replaceState({}, "", url)
}

document.addEventListener("input", (event) => {
  if (event.target.matches("[data-catalog-control]")) {
    search(document.querySelector("form[data-auto-submit]"))
    return
  }

  const form = event.target.closest("form[data-auto-submit]")
  if (!form) return

  if (!event.isComposing) event.target.value = event.target.value.normalize("NFC")
  search(form)
})

document.addEventListener("compositionend", (event) => {
  const form = event.target.closest("form[data-auto-submit]")
  if (!form) return

  event.target.value = event.target.value.normalize("NFC")
  search(form)
})

document.addEventListener("submit", (event) => {
  const form = event.target.closest("form[data-auto-submit]")
  if (!form) return

  event.preventDefault()
  search(form)
})

document.addEventListener("click", (event) => {
  const likeButton = event.target.closest("[data-like-button]")
  if (likeButton) {
    event.preventDefault()
    if (likeButton.dataset.likeLoginRequired !== undefined) {
      showCatalogNotice("좋아요는 로그인 후 이용할 수 있습니다.")
    } else if (likeButton.dataset.likeEmailRequired !== undefined) {
      showCatalogNotice("알림 이메일을 인증한 뒤 좋아요를 이용할 수 있습니다.")
    } else {
      toggleLike(likeButton)
    }
    return
  }

  const detailCard = event.target.closest("[data-detail-url]")
  if (detailCard && !event.target.closest("a, button, input, select, label")) {
    window.location.assign(detailCard.dataset.detailUrl)
    return
  }

  if (!event.target.closest("[data-catalog-clear]")) return

  event.preventDefault()
  const input = document.querySelector("form[data-auto-submit] input[name='q']")
  input.value = ""
  document.querySelectorAll("[data-catalog-control]").forEach((control) => {
    if (control.type === "checkbox") control.checked = false
    else control.value = control.matches("[data-catalog-sort]") ? "relevance" : ""
  })
  search(input.form)
  input.focus()
})

const requestHeaders = () => {
  const headers = { "Accept": "application/json" }
  const token = document.querySelector("meta[name='csrf-token']")?.content
  if (token) headers["X-CSRF-Token"] = token
  return headers
}

const showCatalogNotice = (message) => {
  const notice = document.querySelector("[data-like-notice], [data-catalog-notice]")
  if (!notice) return
  notice.textContent = message
  notice.hidden = false
  notice.focus()
}

const toggleLike = (button) => {
  button.disabled = true
  fetch(button.dataset.likeUrl, { method: "POST", headers: requestHeaders() })
    .then((response) => {
      if (!response.ok) throw new Error("like failed")
      return response.json()
    })
    .then(({ liked, count }) => {
      const card = button.closest("[data-catalog-card]")
      if (card) card.dataset.likes = count
      button.classList.toggle("liked", liked)
      button.setAttribute("aria-pressed", liked)
      button.querySelector("[data-like-icon]").textContent = liked ? "♥" : "♡"
      button.querySelector("[data-like-count]").textContent = count
      showCatalogNotice(liked ? "관심 상품에 추가했습니다. 재입고와 가격 변동을 모두 즉시 이메일로 알려드릴게요." : "관심 상품에서 제거했습니다.")
      const catalogForm = document.querySelector("form[data-auto-submit]")
      if (catalogForm) search(catalogForm)
    })
    .catch(() => showCatalogNotice("좋아요를 처리하지 못했습니다. 잠시 후 다시 시도해 주세요."))
    .finally(() => { button.disabled = false })
}

document.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll("form[data-auto-submit]").forEach(search)
})

window.addEventListener("pageshow", () => {
  const detailCount = document.querySelector("[data-detail-view-count]")
  if (detailCount) sessionStorage.setItem(`listing-view-count:${detailCount.dataset.listingId}`, detailCount.dataset.viewCount)

  document.querySelectorAll("[data-catalog-card]").forEach((card) => {
    const storedCount = sessionStorage.getItem(`listing-view-count:${card.dataset.listingId}`)
    if (storedCount === null || Number(storedCount) <= Number(card.dataset.clicks)) return
    card.dataset.clicks = storedCount
    card.querySelector("[data-click-count]").textContent = storedCount
  })
})
