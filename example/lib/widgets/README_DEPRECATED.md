# Deprecated Widgets

⚠️ **DEPRECATED** - These widgets are deprecated and should not be used in new code.

The DICOM viewer has been migrated to a clean architecture with the following structure:

## New Architecture (Recommended)

- **Core**: `/lib/core/` - Error handling, Result types
- **Domain**: `/lib/domain/` - Entities, repositories, use cases  
- **Data**: `/lib/data/` - Repository implementations, mappers
- **Presentation**: `/lib/presentation/` - Controllers, widgets, UI

### Main Entry Points:
- `CleanDicomViewer` - Main viewer widget
- `DicomViewerController` - Business logic controller
- `ImageInteractionController` - Interaction handling

## Deprecated Files:

### Legacy Widgets (DO NOT USE):
- `dicom_interaction_mixin.dart` - Replaced by `ImageInteractionController`
- `dicom_viewer_base.dart` - Replaced by `CleanDicomViewer`
- `image_viewer.dart` - Replaced by `ImageDisplayWidget`
- `measurable_image.dart` - Replaced by `MeasurementOverlayWidget`
- `measurement_overlay.dart` - Replaced by `MeasurementOverlayWidget`
- `measurement_toolbar.dart` - Replaced by `MeasurementToolbarWidget`
- `metadata_panel.dart` - Legacy metadata display
- `metadata_viewer.dart` - Legacy metadata display
- `simple_dicom_viewer.dart` - Replaced by `CleanDicomViewer`
- `unified_image_controller.dart` - Replaced by `ImageInteractionController`
- `volume_viewer.dart` - Legacy volume rendering

### Migration Path:

Replace old implementations:
```dart
// OLD (deprecated)
import '../widgets/dicom_viewer_base.dart';
DicomViewerBase(...)

// NEW (recommended)
import '../presentation/widgets/clean_dicom_viewer.dart';
CleanDicomViewer(...)
```

### Benefits of New Architecture:

✅ **Clean Architecture** - Separation of concerns
✅ **Better Testing** - Testable business logic
✅ **Type Safety** - Result types for error handling
✅ **Performance** - Optimized image loading
✅ **Maintainability** - Clear dependencies
✅ **Modern UI** - Enhanced user experience
✅ **Configurability** - Feature toggles
✅ **Documentation** - Comprehensive help system

### Breaking Changes:

1. **Constructor Changes**: Controllers now use dependency injection
2. **State Management**: Moved from StatefulWidget to ChangeNotifier
3. **Error Handling**: Now uses Result<T> pattern
4. **File Structure**: Organized by clean architecture layers
5. **API Changes**: Some method names and signatures changed

### For Maintainers:

These deprecated files should be removed in a future version after ensuring no external dependencies remain.

Last Updated: 2024-07-12
Architecture Version: 2.0.0