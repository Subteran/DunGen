# Sprite Sheet Background Artifacts Report

Analysis of stray pixels and artifacts in **transparent background areas** only.
Character sprites themselves are NOT evaluated - only the empty spaces between/around sprites.

---

## dwarf_sheet.png

**Background Issues:**
- Between Row 1, Col 2-3: Stray pixels visible
- Between Row 2, Col 3-4: Residual pixels
- Between Row 3 sprites: Scattered dark pixels in transparent areas
- Left edge near Row 3, Col 1: Stray pixels

**Severity**: Moderate - multiple areas with background artifacts

---

## elf_sheet.png

**Background Issues:**
- Between Row 3, Col 2-3: Visible stray pixels
- Between Row 3 and Row 4: Several dark stray pixels
- Right edge near Row 2, Col 4: Residual pixels
- Between Row 2 sprites: Scattered background pixels

**Severity**: Moderate - consistent artifacts between rows

---

## gnome_sheet.png

**Background Issues:**
- Between Row 1 and Row 2: Stray dark pixels
- Between Row 2, Col 3-4: Visible residual pixels
- Between Row 3, Col 1-2: Scattered background artifacts
- Between Row 3 and Row 4: Several stray pixels

**Severity**: Moderate - artifacts distributed across multiple areas

---

## half-elf_sheet.png

**Background Issues:**
- Between Row 2 and Row 3: Noticeable stray pixels
- Between Row 3, Col 2-3: Visible artifacts
- Between Row 1, Col 1-2: Residual pixels

**Severity**: Mild to Moderate - fewer issues than some other sheets

---

## half-orc_sheet.png

**Background Issues:**
- Between Row 1, Col 3-4: Some stray pixels
- Between Row 2 and Row 3: A few scattered artifacts

**Severity**: MINIMAL - This is the cleanest sheet for background artifacts ✓

---

## halfling_sheet.png

**Background Issues:**
- Between Row 1, Col 2-3: Visible stray pixels
- Between Row 2 and Row 3: Several scattered background artifacts
- Between Row 3, Col 3-4: Noticeable residual pixels
- Between Row 4, Col 2-3: Dark stray pixels visible

**Severity**: Moderate - distributed artifacts across multiple zones

---

## human_sheet.png

**Background Issues:**
- Between Row 1, Col 2-3: Stray pixels visible
- Between Row 2 and Row 3: Several background artifacts
- Between Row 3, Col 2-3: Visible residual pixels
- Between Row 4 sprites: Scattered stray pixels

**Severity**: Moderate - consistent with other problem sheets

---

## ursa_sheet.png

**Background Issues:**
- Between Row 1 and Row 2: Stray pixels in background
- Between Row 2, Col 3-4: Visible background artifacts
- Between Row 3 and Row 4: Scattered residual pixels
- Between Row 4, Col 2-3: Stray dark pixels

**Severity**: Moderate - similar to other sheets

---

## Summary & Priority

### Cleanest (needs least cleanup):
1. **half-orc_sheet.png** ✓ - Minimal background artifacts

### Moderate Cleanup Needed (all roughly equal):
2. dwarf_sheet.png
3. elf_sheet.png
4. gnome_sheet.png
5. half-elf_sheet.png
6. halfling_sheet.png
7. human_sheet.png
8. ursa_sheet.png

### Common Problem Areas Across All Sheets:
- **Between Row 2 and Row 3**: Most sheets have artifacts here
- **Between Row 3 sprites**: Frequent stray pixels
- **Between columns in Row 3-4**: Consistent artifacts

### Likely Cause:
These look like **editing residue** - stray pixels left behind from:
- Copy/paste operations
- Eraser tool not fully cleaning edges
- Layer compositing artifacts
- Export/save artifacts from image editing software

---

## Recommended Cleanup Process

1. **Batch Process**: Open all sheets simultaneously in image editor
2. **Focus on horizontal gaps**: Between Row 2-3 and Row 3-4 (most problematic)
3. **Use Magic Wand/Select by Color**: Select all non-transparent pixels in background areas
4. **Verify selection**: Ensure no character pixels selected
5. **Delete**: Remove all selected stray pixels
6. **Check edges**: Scan sheet edges for residual pixels
7. **Re-export**: Save as PNG with full transparency

### Testing After Cleanup:
- View each sheet at 100% zoom
- Check all gaps between sprites
- Verify no character pixels were accidentally removed
- Test in-game to ensure sprites still display correctly

---

## Notes

- All artifacts are **background only** - character sprites appear intact
- Most artifacts are 1-3 pixel clusters
- Artifacts are generally dark/black pixels
- These won't be visible in-game on most backgrounds but should be cleaned for completeness
