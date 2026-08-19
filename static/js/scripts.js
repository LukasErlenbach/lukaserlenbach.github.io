// Mobile navigation toggle
;(function () {
    var menu = document.getElementById("js-menu")
    var toggle = document.getElementById("js-navbar-toggle")
    if (!menu || !toggle) return

    toggle.addEventListener("click", function () {
        var isOpen = menu.classList.toggle("active")
        toggle.classList.toggle("is-open", isOpen)
        toggle.setAttribute("aria-expanded", String(isOpen))
        toggle.setAttribute("aria-label", isOpen ? "Close menu" : "Open menu")
    })

    document.addEventListener("keyup", function (event) {
        if (event.key === "Escape" && menu.classList.contains("active")) {
            toggle.click()
            toggle.focus()
        }
    })
})()

// Theme toggle. The initial class is set by the inline script in <head>
// (templates/head.html) so the first paint already has the right theme.
;(function () {
    var toggle = document.getElementById("dark-mode-toggle")
    var iconMoon = document.getElementById("icon-moon")
    var iconSun = document.getElementById("icon-sun")
    if (!toggle || !iconMoon || !iconSun) return
    var DARK_CLASS = "dark-mode"

    function renderTheme(isDark) {
        iconMoon.style.display = isDark ? "inline" : "none"
        iconSun.style.display = isDark ? "none" : "inline"
        toggle.setAttribute("aria-pressed", String(isDark))
    }

    renderTheme(document.documentElement.classList.contains(DARK_CLASS))

    toggle.addEventListener("click", function () {
        var nowDark = document.documentElement.classList.toggle(DARK_CLASS)
        localStorage.setItem("theme", nowDark ? "dark" : "light")
        renderTheme(nowDark)
    })
})()
