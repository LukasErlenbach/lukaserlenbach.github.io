// Email links are shipped as data-name/domain/tld so the address is not in
// the HTML for scrapers; assemble href and visible text here.
;(function () {
    var mailLinks = document.querySelectorAll("a[data-name][data-domain][data-tld]")
    Array.prototype.forEach.call(mailLinks, function (link) {
        var address = link.dataset.name + "@" + link.dataset.domain + "." + link.dataset.tld
        link.href = "mailto:" + address
        if (link.classList.contains("crypted-mail")) link.textContent = address
    })
})()

// Mobile navigation toggle
;(function () {
    var menu = document.getElementById("js-menu")
    var toggle = document.getElementById("js-navbar-toggle")
    if (!menu || !toggle) return

    toggle.addEventListener("click", function () {
        var isOpen = menu.classList.toggle("active")
        toggle.classList.toggle("is-open", isOpen)
        toggle.setAttribute("aria-expanded", String(isOpen))
    })

    document.addEventListener("keyup", function (event) {
        if (event.key === "Escape" && menu.classList.contains("active")) {
            toggle.click()
            toggle.focus()
        }
    })
})()

// Theme toggle. The initial class is set by the inline script in <head>
// (templates/head.html) so the first paint already has the right theme;
// which icon shows is pure CSS keyed on html.dark-mode.
;(function () {
    var toggle = document.getElementById("dark-mode-toggle")
    if (!toggle) return
    var DARK_CLASS = "dark-mode"

    toggle.setAttribute("aria-pressed", String(document.documentElement.classList.contains(DARK_CLASS)))

    toggle.addEventListener("click", function () {
        var isDark = document.documentElement.classList.toggle(DARK_CLASS)
        toggle.setAttribute("aria-pressed", String(isDark))
        try { localStorage.setItem("theme", isDark ? "dark" : "light") } catch (e) { /* storage disabled: theme still toggles for this page */ }
    })
})()
