# DICOM Loading Debug Guide

## How to Debug Loading Issues

### 1. Enable Debug Console
Run your Flutter app with debug output:
```bash
flutter run --debug
```

### 2. Debug Output Locations
The enhanced logging will show detailed information in the debug console:

#### File Selection Phase:
- `📂 Starting directory/file selection...`
- `📂 Selection result: X files`
- `🔍 Validating X selected files...`
- `🔍 Validating file 1/X: filename.dcm`
- `✅ Valid DICOM file: filename.dcm` or `❌ Invalid DICOM file: filename.dcm`

#### Loading Phase:
- `🚀 Starting navigation to loading screen...`
- `🔄 Starting loading task...`
- `📄 Loading X files...`
- `📄 File 0: filename.dcm (12345 bytes)`
- `✅ Loading task completed successfully`

#### Error Information:
- `❌ Loading task failed: [error details]`
- `❌ Stack trace: [full stack trace]`

### 3. Common Issues and Solutions

#### Issue: "Failed to load DICOM files" 
**Debug Steps:**
1. Check console for `❌ Loading task failed:` messages
2. Look for stack traces starting with `❌ Stack trace:`
3. Check if files are valid DICOM format
4. Verify file permissions and accessibility

#### Issue: "No files selected"
**Debug Steps:**
1. Check if `📂 Selection result: 0 files` appears
2. Look for `❌ Invalid DICOM file:` messages
3. Verify selected directory contains .dcm files
4. Check file format and extensions

#### Issue: Loading screen hangs
**Debug Steps:**
1. Look for `🔄 Starting loading task...` without completion
2. Check for validation errors on specific files
3. Monitor progress messages for stuck files

### 4. Debug Console Commands
When debugging, look for these key indicators:

**Successful Flow:**
```
📂 Starting directory/file selection...
📂 Selected directory: /path/to/dicom/files
🔍 Scanning for DICOM files...
✅ Directory scan complete: 5 DICOM files found
🚀 Starting navigation to loading screen...
🔄 Starting loading task...
📄 Loading 5 files...
✅ Loading task completed successfully
✅ Loading successful - updating UI
```

**Error Flow:**
```
📂 Starting directory/file selection...
❌ Error selecting directory: [specific error]
❌ Stack trace: [detailed trace]
❌ Loading failed - showing error
```

### 5. File Validation Details
Each file goes through this process:
1. **Extension Check**: .dcm, .dicom, .ima
2. **Content Validation**: DICOM header verification
3. **Metadata Extraction**: Patient info, study details
4. **Image Data Loading**: Pixel data processing

### 6. Common Error Patterns

#### Pattern 1: Permission Denied
```
❌ Error validating file: FileSystemException: Cannot open file
```
**Solution**: Check file/directory permissions

#### Pattern 2: Invalid DICOM Format
```
❌ Invalid DICOM file: filename.dcm
```
**Solution**: Verify file is valid DICOM format

#### Pattern 3: Memory Issues
```
❌ Loading task failed: Out of memory
```
**Solution**: Process fewer files at once or increase available memory

### 7. Manual Testing Steps
1. **Test with single file**: Use "Select Individual Files" first
2. **Check file properties**: Verify DICOM file headers
3. **Try different directories**: Test with known good DICOM files
4. **Monitor memory usage**: Watch for memory-related crashes

### 8. Report Issues
When reporting bugs, include:
- Full debug console output
- File details (size, format, source)
- Platform (iOS, Android, Desktop, Web)
- Steps to reproduce
- Expected vs actual behavior