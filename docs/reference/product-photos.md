# Sellable-product reference images

Status: generated assets used in source and design preview. Date: 2026-10-26. Source: owner request to add reference images to product cards. Tool: built-in image_gen (no CLI).

Images are eight local PNGs in `app/ui/photos/`. They are generated reference examples, not actual restaurant-product photos or evidence of portion size. Screen/data remain local and load no external-network images. Keys and the allowlist are documented in `model.js`; image selection is in the inventory product form.

## Final generation prompt set

Each independent request uses the following text, replacing SUBJECT from the table:

> Use case: product-mockup. Asset type: local restaurant POS product thumbnail, square photograph. Primary request: SUBJECT. Style: realistic professional food reference photography, not an actual photograph of the restaurant's products. Single centered subject on a warm light beige tabletop, soft natural daylight, camera at 40 degree angle, appetizing but honest portion, image fills frame, quiet neutral background, crisp recognizable subject at small thumbnail sizes. No text, lettering, logo, watermark, hands, extra dishes or borders.

| File | SUBJECT |
| --- | --- |
| `beef-kebab.png` | Iraqi grilled minced beef kebab, three long grilled skewers with char marks, served on a simple ivory ceramic plate with grilled tomato and parsley, no bread covering the meat |
| `chicken-kebab.png` | Iraqi grilled minced chicken kebab, three long pale golden grilled skewers with char marks, served on an ivory ceramic plate with grilled tomato and parsley |
| `grilled-chicken.png` | Iraqi half chicken grilled over charcoal, golden brown crispy skin and subtle char marks, ivory plate with a small lemon wedge |
| `dulaimiya.png` | Iraqi chicken dulaimiya on an ivory platter: aromatic rice over torn flatbread with a clearly visible golden roasted chicken quarter on top |
| `red-rice.png` | a small ivory bowl of Iraqi tomato red rice, fluffy individual grains, a small parsley garnish |
| `appetizers.png` | an ivory small plate of Iraqi fresh salad with cucumber tomato lettuce, plus a small hummus portion and pickled vegetables, neat restaurant appetizer |
| `water.png` | a single clear unbranded plastic water bottle with blue cap and a small transparent tumbler, no printed words or labels |
| `cola.png` | a chilled unbranded dark cola in a clear glass with ice cubes and tiny bubbles, simple small glass beverage photography, no can and no branding |

Each generated image was copied into the project while preserving its original. Images/cards and local loading were visually inspected in an Electron experiment. Verification details are in the [second-round log](../log/2026-10-26-sales-layout-review.md).
