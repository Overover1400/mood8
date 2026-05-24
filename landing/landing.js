// Gentle reveal-on-scroll for feature + why cards. Tiny vanilla
// implementation — no framework, runs once, then disconnects.
(function () {
  if (!('IntersectionObserver' in window)) return;

  const targets = document.querySelectorAll('.card, .why-row, .download-card');
  targets.forEach((el) => {
    el.style.opacity = '0';
    el.style.transform = 'translateY(14px)';
    el.style.transition = 'opacity 600ms ease, transform 600ms ease';
  });

  const io = new IntersectionObserver(
    (entries) => {
      entries.forEach((e) => {
        if (!e.isIntersecting) return;
        const el = e.target;
        el.style.opacity = '1';
        el.style.transform = 'translateY(0)';
        io.unobserve(el);
      });
    },
    { rootMargin: '0px 0px -80px 0px', threshold: 0.05 },
  );

  targets.forEach((el) => io.observe(el));
})();
