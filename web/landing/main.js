// Scroll-triggered reveal. Cheap IntersectionObserver — no library.
(function () {
  const targets = document.querySelectorAll('.reveal');
  if (!('IntersectionObserver' in window) || targets.length === 0) {
    targets.forEach((el) => el.classList.add('is-visible'));
    return;
  }
  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add('is-visible');
          observer.unobserve(entry.target);
        }
      });
    },
    { threshold: 0.12, rootMargin: '0px 0px -10% 0px' }
  );
  targets.forEach((el) => observer.observe(el));
})();

// Close other <details> when one opens — single-open accordion behavior.
(function () {
  const detailsAll = document.querySelectorAll('.faq details');
  detailsAll.forEach((d) => {
    d.addEventListener('toggle', () => {
      if (!d.open) return;
      detailsAll.forEach((other) => {
        if (other !== d) other.open = false;
      });
    });
  });
})();

// Slight parallax for the background glows. No-op if reduced motion.
(function () {
  const prefersReduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  if (prefersReduce) return;
  const tl = document.querySelector('.bg-glow-tl');
  const br = document.querySelector('.bg-glow-br');
  if (!tl || !br) return;
  window.addEventListener(
    'scroll',
    () => {
      const y = window.scrollY;
      tl.style.transform = 'translateY(' + y * 0.08 + 'px)';
      br.style.transform = 'translateY(' + y * -0.05 + 'px)';
    },
    { passive: true }
  );
})();
