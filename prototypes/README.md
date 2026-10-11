# FXTrack Static Prototype

Open `index.html` in a browser, or serve this folder with:

```sh
python3 -m http.server 4173 --directory prototypes --bind 127.0.0.1
```

Then open http://localhost:4173/index.html. No dependencies or build step.

`theme.css` is the durable shared token source. Every HTML screen links it and
contains its layout CSS. Port tokens to the Rails Tailwind v4 stylesheet during
the first UI feature. Main application source is unchanged.

Reference screenshots are retained in local-only `blueprint/reference/`.
Desktop and mobile layouts reproduce their navy/blue/teal visual direction.
The landing uses an HTML chart preview instead of the screenshot's mountain/device
composite, keeping all text and controls responsive and readable. Public signup,
pricing, fabricated usage metrics and performance promises are omitted per PRD.
The registration layout is an owner-provisioning preview. AUD/USD SELL levels are
corrected to stop above entry and target below entry. Sizing is explicitly a sample
estimate with stated conversion/rounding assumptions; it is not a working calculator.

Try the landing demo link, login/recovery previews, signal details, H1/H4 links,
mobile drawer and journal cards, pair toggles and alert preference controls.
Buttons marked demo only do not persist, authenticate, dispatch alerts or perform
market calculations. Never enter real secrets. No real market data is loaded.

Keep prototypes in source control until the theme is ported. No commit is made by
the prototype task. These HTML files are design references, not completed features.

## Brand assets

The four supplied SVGs are stored in `app/assets/images/` and
`prototypes/assets/`. Dark wordmarks appear in navigation, light wordmarks in
white authentication cards, the icon on the landing/directory, and the favicon
on every screen. Shared theme colors match the supplied blue, green and navy.
The wordmarks use a compact canvas, tightened symbol-to-text spacing and balanced
text weight, with proportional sizing across desktop and mobile navigation.

The dark wordmark now has a transparent canvas and the logo containers have no
solid background, so the mark blends into the landing and navigation surfaces.
