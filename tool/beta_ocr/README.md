# Reading beta screenshots

The files here are the helpers used to turn the screenshots of single cards (1280x764, the card in the middle with the
PICK / UPGRADE / SELL buttons) into `tool/beta_cards_source.csv`. They are kept so new screenshots can be added later.

- `ocr1280.py`: where every field is on the screenshot (`BOX`, the card always sits in the same place) and the Tesseract helpers.
  Set `CARDS_DIR` to the folder with the screenshots. Needs `tesseract-ocr`, `pytesseract`, `opencv-python`, `numpy`.
- `glyphs.py` + `cardread.py` + `*.npy`: reading the digits by shape. Tesseract mixes up 5 / 9 / 3 / 8 / 2 on these cards,
  so the digits are cut out and matched to the nearest sample glyph (`stcent.npy` numbers, `rqcent.npy` RQ badge, `drivecent.npy` R / F / 4).
  `cardread.read_card(image)` returns the numbers, the drive, the country and a rough name.
- Names are the weak part: Tesseract is wrong on about one name in eight (a bold brand next to a thin model, light photos behind the text).
  The 334 cards of `cards.zip` were checked by eye, cut-out header bars are enough for that (see `BOX['name']`).
- The class comes from the colour of the RQ badge / the line under the card: Common (grey) D, Uncommon (green) C, Rare (blue) B,
  Super Rare (purple) A, Legendary (yellow) S. RQ itself does not decide it (an RQ 5 exists as common and as uncommon).
