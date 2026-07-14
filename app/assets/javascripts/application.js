const search = (form) => {
  const input = form.querySelector("input[name='q']")
  const query = input.value.normalize("NFC").trim()
  const needle = query.toLocaleLowerCase("ko")
  const cards = document.querySelectorAll("[data-catalog-card]")
  let count = 0

  cards.forEach((card) => {
    const matches = !needle || card.dataset.searchText.includes(needle)
    card.hidden = !matches || count >= 50
    if (matches) count += 1
  })

  document.querySelector("[data-catalog-title]").textContent = query ? `검색 결과 ${count}개` : `현재 수집 만년필 ${count}개`
  document.querySelector("[data-catalog-summary]").textContent = query ? `“${query}” · ` : "최근 정상 확인순 최대 50개"
  document.querySelector("[data-catalog-clear]").hidden = !query
  document.querySelector("[data-catalog-empty]").hidden = count > 0
  document.querySelector("[data-catalog-empty]").textContent = query ? "검색 결과가 없습니다." : "아직 정상 수집된 상품이 없습니다."
  document.querySelector("[data-catalog-cards]").hidden = count === 0

  const url = new URL(form.action, window.location.href)
  query ? url.searchParams.set("q", query) : url.searchParams.delete("q")
  history.replaceState({}, "", url)
}

document.addEventListener("input", (event) => {
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
  if (!event.target.closest("[data-catalog-clear]")) return

  event.preventDefault()
  const input = document.querySelector("form[data-auto-submit] input[name='q']")
  input.value = ""
  search(input.form)
  input.focus()
})
