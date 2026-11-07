# Example studies: sources and licenses

The example studies bundled with the viewer are de-identified research images
from the [NCI Imaging Data Commons](https://portal.imaging.datacommons.cancer.gov/).
They are used under the
[Creative Commons Attribution 4.0 International license (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/).
Each file is marked `PatientIdentityRemoved: YES` and was de-identified by the
data provider following DICOM PS3.15 Annex E.

## chest_ct/

- 16 axial slices from a chest CT, neck to upper abdomen (series "LUNG",
  512×512, 5 mm).
- Source: Cancer Moonshot Biobank - Invasive Breast Carcinoma Cancer
  Collection (CMB-BRCA), https://doi.org/10.7937/dx22-8j71
- Changes: every fourth slice of the 63-slice series was kept and the files
  were renamed `ct_01.dcm`…`ct_16.dcm` in slice order. File contents are
  unchanged.

## head_mr/

- 26 coronal slices from a head MR (series "T2 COR BLADE", 320×320).
- Source: Cancer Moonshot Biobank - Lung Cancer Collection (CMB-LCA),
  https://doi.org/10.7937/3cx3-s132
- Changes: files renamed `mr_01.dcm`…`mr_26.dcm` in slice order. File
  contents are unchanged.

## chest_xray/

- One portable AP chest radiograph (CR, 1760×2140).
- Source: COVID-19-AR, Chest Imaging with Clinical and Genomic Correlates
  Representing a Rural COVID-19 Positive Population,
  https://doi.org/10.7937/tcia.2020.py71-5978
- Changes: file renamed `xray_01.dcm`. File contents are unchanged.

## Citation

When you publish work that uses these images, cite the collections above and
the Imaging Data Commons:

> Fedorov, A., et al. "National Cancer Institute Imaging Data Commons: Toward
> Transparency, Reproducibility, and Scalability in Imaging Artificial
> Intelligence." RadioGraphics 43.12 (2023). https://doi.org/10.1148/rg.230180
