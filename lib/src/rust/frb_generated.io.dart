// This file is automatically generated, so please do not edit it.
// @generated by `flutter_rust_bridge`@ 2.8.0.

// ignore_for_file: unused_import, unused_element, unnecessary_import, duplicate_ignore, invalid_use_of_internal_member, annotate_overrides, non_constant_identifier_names, curly_braces_in_flow_control_structures, prefer_const_literals_to_create_immutables, unused_field

import 'api/dicom_rs_interface.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'frb_generated.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated_io.dart';

abstract class RustLibApiImplPlatform extends BaseApiImpl<RustLibWire> {
  RustLibApiImplPlatform({
    required super.handler,
    required super.wire,
    required super.generalizedFrbRustBinding,
    required super.portManager,
  });

  CrossPlatformFinalizerArg get rust_arc_decrement_strong_count_ElPtr =>
      wire._rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerElPtr;

  @protected
  AnyhowException dco_decode_AnyhowException(dynamic raw);

  @protected
  El
  dco_decode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEl(
    dynamic raw,
  );

  @protected
  El
  dco_decode_Auto_RefMut_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEl(
    dynamic raw,
  );

  @protected
  El
  dco_decode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEl(
    dynamic raw,
  );

  @protected
  FutureOr<void> Function(int, int)
  dco_decode_DartFn_Inputs_u_32_u_32_Output_unit_AnyhowException(dynamic raw);

  @protected
  Object dco_decode_DartOpaque(dynamic raw);

  @protected
  Map<String, Map<String, DicomTag>> dco_decode_Map_String_Map_String_dicom_tag(
    dynamic raw,
  );

  @protected
  Map<String, DicomTag> dco_decode_Map_String_dicom_tag(dynamic raw);

  @protected
  Map<String, DicomValueType> dco_decode_Map_String_dicom_value_type(
    dynamic raw,
  );

  @protected
  El
  dco_decode_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEl(
    dynamic raw,
  );

  @protected
  String dco_decode_String(dynamic raw);

  @protected
  bool dco_decode_bool(dynamic raw);

  @protected
  DicomHandler dco_decode_box_autoadd_dicom_handler(dynamic raw);

  @protected
  double dco_decode_box_autoadd_f_64(dynamic raw);

  @protected
  int dco_decode_box_autoadd_i_32(dynamic raw);

  @protected
  int dco_decode_box_autoadd_u_16(dynamic raw);

  @protected
  int dco_decode_box_autoadd_u_32(dynamic raw);

  @protected
  DicomDirEntry dco_decode_dicom_dir_entry(dynamic raw);

  @protected
  DicomDirectoryEntry dco_decode_dicom_directory_entry(dynamic raw);

  @protected
  DicomFile dco_decode_dicom_file(dynamic raw);

  @protected
  DicomHandler dco_decode_dicom_handler(dynamic raw);

  @protected
  DicomImage dco_decode_dicom_image(dynamic raw);

  @protected
  DicomInstance dco_decode_dicom_instance(dynamic raw);

  @protected
  DicomMetadata dco_decode_dicom_metadata(dynamic raw);

  @protected
  DicomMetadataMap dco_decode_dicom_metadata_map(dynamic raw);

  @protected
  DicomPatient dco_decode_dicom_patient(dynamic raw);

  @protected
  DicomSeries dco_decode_dicom_series(dynamic raw);

  @protected
  DicomSlice dco_decode_dicom_slice(dynamic raw);

  @protected
  DicomStudy dco_decode_dicom_study(dynamic raw);

  @protected
  DicomTag dco_decode_dicom_tag(dynamic raw);

  @protected
  DicomValueType dco_decode_dicom_value_type(dynamic raw);

  @protected
  DicomVolume dco_decode_dicom_volume(dynamic raw);

  @protected
  double dco_decode_f_32(dynamic raw);

  @protected
  double dco_decode_f_64(dynamic raw);

  @protected
  int dco_decode_i_32(dynamic raw);

  @protected
  PlatformInt64 dco_decode_isize(dynamic raw);

  @protected
  List<String> dco_decode_list_String(dynamic raw);

  @protected
  List<DicomDirEntry> dco_decode_list_dicom_dir_entry(dynamic raw);

  @protected
  List<DicomDirectoryEntry> dco_decode_list_dicom_directory_entry(dynamic raw);

  @protected
  List<DicomInstance> dco_decode_list_dicom_instance(dynamic raw);

  @protected
  List<DicomPatient> dco_decode_list_dicom_patient(dynamic raw);

  @protected
  List<DicomSeries> dco_decode_list_dicom_series(dynamic raw);

  @protected
  List<DicomSlice> dco_decode_list_dicom_slice(dynamic raw);

  @protected
  List<DicomStudy> dco_decode_list_dicom_study(dynamic raw);

  @protected
  List<DicomTag> dco_decode_list_dicom_tag(dynamic raw);

  @protected
  Float32List dco_decode_list_prim_f_32_strict(dynamic raw);

  @protected
  Float64List dco_decode_list_prim_f_64_strict(dynamic raw);

  @protected
  Int32List dco_decode_list_prim_i_32_strict(dynamic raw);

  @protected
  List<int> dco_decode_list_prim_u_8_loose(dynamic raw);

  @protected
  Uint8List dco_decode_list_prim_u_8_strict(dynamic raw);

  @protected
  List<(String, DicomTag)> dco_decode_list_record_string_dicom_tag(dynamic raw);

  @protected
  List<(String, DicomValueType)> dco_decode_list_record_string_dicom_value_type(
    dynamic raw,
  );

  @protected
  List<(String, Map<String, DicomTag>)>
  dco_decode_list_record_string_map_string_dicom_tag(dynamic raw);

  @protected
  String? dco_decode_opt_String(dynamic raw);

  @protected
  double? dco_decode_opt_box_autoadd_f_64(dynamic raw);

  @protected
  int? dco_decode_opt_box_autoadd_i_32(dynamic raw);

  @protected
  int? dco_decode_opt_box_autoadd_u_16(dynamic raw);

  @protected
  int? dco_decode_opt_box_autoadd_u_32(dynamic raw);

  @protected
  Float64List? dco_decode_opt_list_prim_f_64_strict(dynamic raw);

  @protected
  (double, double, double) dco_decode_record_f_64_f_64_f_64(dynamic raw);

  @protected
  (String, DicomTag) dco_decode_record_string_dicom_tag(dynamic raw);

  @protected
  (String, DicomValueType) dco_decode_record_string_dicom_value_type(
    dynamic raw,
  );

  @protected
  (String, Map<String, DicomTag>) dco_decode_record_string_map_string_dicom_tag(
    dynamic raw,
  );

  @protected
  int dco_decode_u_16(dynamic raw);

  @protected
  int dco_decode_u_32(dynamic raw);

  @protected
  int dco_decode_u_8(dynamic raw);

  @protected
  void dco_decode_unit(dynamic raw);

  @protected
  BigInt dco_decode_usize(dynamic raw);

  @protected
  AnyhowException sse_decode_AnyhowException(SseDeserializer deserializer);

  @protected
  El
  sse_decode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEl(
    SseDeserializer deserializer,
  );

  @protected
  El
  sse_decode_Auto_RefMut_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEl(
    SseDeserializer deserializer,
  );

  @protected
  El
  sse_decode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEl(
    SseDeserializer deserializer,
  );

  @protected
  Object sse_decode_DartOpaque(SseDeserializer deserializer);

  @protected
  Map<String, Map<String, DicomTag>> sse_decode_Map_String_Map_String_dicom_tag(
    SseDeserializer deserializer,
  );

  @protected
  Map<String, DicomTag> sse_decode_Map_String_dicom_tag(
    SseDeserializer deserializer,
  );

  @protected
  Map<String, DicomValueType> sse_decode_Map_String_dicom_value_type(
    SseDeserializer deserializer,
  );

  @protected
  El
  sse_decode_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEl(
    SseDeserializer deserializer,
  );

  @protected
  String sse_decode_String(SseDeserializer deserializer);

  @protected
  bool sse_decode_bool(SseDeserializer deserializer);

  @protected
  DicomHandler sse_decode_box_autoadd_dicom_handler(
    SseDeserializer deserializer,
  );

  @protected
  double sse_decode_box_autoadd_f_64(SseDeserializer deserializer);

  @protected
  int sse_decode_box_autoadd_i_32(SseDeserializer deserializer);

  @protected
  int sse_decode_box_autoadd_u_16(SseDeserializer deserializer);

  @protected
  int sse_decode_box_autoadd_u_32(SseDeserializer deserializer);

  @protected
  DicomDirEntry sse_decode_dicom_dir_entry(SseDeserializer deserializer);

  @protected
  DicomDirectoryEntry sse_decode_dicom_directory_entry(
    SseDeserializer deserializer,
  );

  @protected
  DicomFile sse_decode_dicom_file(SseDeserializer deserializer);

  @protected
  DicomHandler sse_decode_dicom_handler(SseDeserializer deserializer);

  @protected
  DicomImage sse_decode_dicom_image(SseDeserializer deserializer);

  @protected
  DicomInstance sse_decode_dicom_instance(SseDeserializer deserializer);

  @protected
  DicomMetadata sse_decode_dicom_metadata(SseDeserializer deserializer);

  @protected
  DicomMetadataMap sse_decode_dicom_metadata_map(SseDeserializer deserializer);

  @protected
  DicomPatient sse_decode_dicom_patient(SseDeserializer deserializer);

  @protected
  DicomSeries sse_decode_dicom_series(SseDeserializer deserializer);

  @protected
  DicomSlice sse_decode_dicom_slice(SseDeserializer deserializer);

  @protected
  DicomStudy sse_decode_dicom_study(SseDeserializer deserializer);

  @protected
  DicomTag sse_decode_dicom_tag(SseDeserializer deserializer);

  @protected
  DicomValueType sse_decode_dicom_value_type(SseDeserializer deserializer);

  @protected
  DicomVolume sse_decode_dicom_volume(SseDeserializer deserializer);

  @protected
  double sse_decode_f_32(SseDeserializer deserializer);

  @protected
  double sse_decode_f_64(SseDeserializer deserializer);

  @protected
  int sse_decode_i_32(SseDeserializer deserializer);

  @protected
  PlatformInt64 sse_decode_isize(SseDeserializer deserializer);

  @protected
  List<String> sse_decode_list_String(SseDeserializer deserializer);

  @protected
  List<DicomDirEntry> sse_decode_list_dicom_dir_entry(
    SseDeserializer deserializer,
  );

  @protected
  List<DicomDirectoryEntry> sse_decode_list_dicom_directory_entry(
    SseDeserializer deserializer,
  );

  @protected
  List<DicomInstance> sse_decode_list_dicom_instance(
    SseDeserializer deserializer,
  );

  @protected
  List<DicomPatient> sse_decode_list_dicom_patient(
    SseDeserializer deserializer,
  );

  @protected
  List<DicomSeries> sse_decode_list_dicom_series(SseDeserializer deserializer);

  @protected
  List<DicomSlice> sse_decode_list_dicom_slice(SseDeserializer deserializer);

  @protected
  List<DicomStudy> sse_decode_list_dicom_study(SseDeserializer deserializer);

  @protected
  List<DicomTag> sse_decode_list_dicom_tag(SseDeserializer deserializer);

  @protected
  Float32List sse_decode_list_prim_f_32_strict(SseDeserializer deserializer);

  @protected
  Float64List sse_decode_list_prim_f_64_strict(SseDeserializer deserializer);

  @protected
  Int32List sse_decode_list_prim_i_32_strict(SseDeserializer deserializer);

  @protected
  List<int> sse_decode_list_prim_u_8_loose(SseDeserializer deserializer);

  @protected
  Uint8List sse_decode_list_prim_u_8_strict(SseDeserializer deserializer);

  @protected
  List<(String, DicomTag)> sse_decode_list_record_string_dicom_tag(
    SseDeserializer deserializer,
  );

  @protected
  List<(String, DicomValueType)> sse_decode_list_record_string_dicom_value_type(
    SseDeserializer deserializer,
  );

  @protected
  List<(String, Map<String, DicomTag>)>
  sse_decode_list_record_string_map_string_dicom_tag(
    SseDeserializer deserializer,
  );

  @protected
  String? sse_decode_opt_String(SseDeserializer deserializer);

  @protected
  double? sse_decode_opt_box_autoadd_f_64(SseDeserializer deserializer);

  @protected
  int? sse_decode_opt_box_autoadd_i_32(SseDeserializer deserializer);

  @protected
  int? sse_decode_opt_box_autoadd_u_16(SseDeserializer deserializer);

  @protected
  int? sse_decode_opt_box_autoadd_u_32(SseDeserializer deserializer);

  @protected
  Float64List? sse_decode_opt_list_prim_f_64_strict(
    SseDeserializer deserializer,
  );

  @protected
  (double, double, double) sse_decode_record_f_64_f_64_f_64(
    SseDeserializer deserializer,
  );

  @protected
  (String, DicomTag) sse_decode_record_string_dicom_tag(
    SseDeserializer deserializer,
  );

  @protected
  (String, DicomValueType) sse_decode_record_string_dicom_value_type(
    SseDeserializer deserializer,
  );

  @protected
  (String, Map<String, DicomTag>) sse_decode_record_string_map_string_dicom_tag(
    SseDeserializer deserializer,
  );

  @protected
  int sse_decode_u_16(SseDeserializer deserializer);

  @protected
  int sse_decode_u_32(SseDeserializer deserializer);

  @protected
  int sse_decode_u_8(SseDeserializer deserializer);

  @protected
  void sse_decode_unit(SseDeserializer deserializer);

  @protected
  BigInt sse_decode_usize(SseDeserializer deserializer);

  @protected
  void sse_encode_AnyhowException(
    AnyhowException self,
    SseSerializer serializer,
  );

  @protected
  void
  sse_encode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEl(
    El self,
    SseSerializer serializer,
  );

  @protected
  void
  sse_encode_Auto_RefMut_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEl(
    El self,
    SseSerializer serializer,
  );

  @protected
  void
  sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEl(
    El self,
    SseSerializer serializer,
  );

  @protected
  void sse_encode_DartFn_Inputs_u_32_u_32_Output_unit_AnyhowException(
    FutureOr<void> Function(int, int) self,
    SseSerializer serializer,
  );

  @protected
  void sse_encode_DartOpaque(Object self, SseSerializer serializer);

  @protected
  void sse_encode_Map_String_Map_String_dicom_tag(
    Map<String, Map<String, DicomTag>> self,
    SseSerializer serializer,
  );

  @protected
  void sse_encode_Map_String_dicom_tag(
    Map<String, DicomTag> self,
    SseSerializer serializer,
  );

  @protected
  void sse_encode_Map_String_dicom_value_type(
    Map<String, DicomValueType> self,
    SseSerializer serializer,
  );

  @protected
  void
  sse_encode_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEl(
    El self,
    SseSerializer serializer,
  );

  @protected
  void sse_encode_String(String self, SseSerializer serializer);

  @protected
  void sse_encode_bool(bool self, SseSerializer serializer);

  @protected
  void sse_encode_box_autoadd_dicom_handler(
    DicomHandler self,
    SseSerializer serializer,
  );

  @protected
  void sse_encode_box_autoadd_f_64(double self, SseSerializer serializer);

  @protected
  void sse_encode_box_autoadd_i_32(int self, SseSerializer serializer);

  @protected
  void sse_encode_box_autoadd_u_16(int self, SseSerializer serializer);

  @protected
  void sse_encode_box_autoadd_u_32(int self, SseSerializer serializer);

  @protected
  void sse_encode_dicom_dir_entry(DicomDirEntry self, SseSerializer serializer);

  @protected
  void sse_encode_dicom_directory_entry(
    DicomDirectoryEntry self,
    SseSerializer serializer,
  );

  @protected
  void sse_encode_dicom_file(DicomFile self, SseSerializer serializer);

  @protected
  void sse_encode_dicom_handler(DicomHandler self, SseSerializer serializer);

  @protected
  void sse_encode_dicom_image(DicomImage self, SseSerializer serializer);

  @protected
  void sse_encode_dicom_instance(DicomInstance self, SseSerializer serializer);

  @protected
  void sse_encode_dicom_metadata(DicomMetadata self, SseSerializer serializer);

  @protected
  void sse_encode_dicom_metadata_map(
    DicomMetadataMap self,
    SseSerializer serializer,
  );

  @protected
  void sse_encode_dicom_patient(DicomPatient self, SseSerializer serializer);

  @protected
  void sse_encode_dicom_series(DicomSeries self, SseSerializer serializer);

  @protected
  void sse_encode_dicom_slice(DicomSlice self, SseSerializer serializer);

  @protected
  void sse_encode_dicom_study(DicomStudy self, SseSerializer serializer);

  @protected
  void sse_encode_dicom_tag(DicomTag self, SseSerializer serializer);

  @protected
  void sse_encode_dicom_value_type(
    DicomValueType self,
    SseSerializer serializer,
  );

  @protected
  void sse_encode_dicom_volume(DicomVolume self, SseSerializer serializer);

  @protected
  void sse_encode_f_32(double self, SseSerializer serializer);

  @protected
  void sse_encode_f_64(double self, SseSerializer serializer);

  @protected
  void sse_encode_i_32(int self, SseSerializer serializer);

  @protected
  void sse_encode_isize(PlatformInt64 self, SseSerializer serializer);

  @protected
  void sse_encode_list_String(List<String> self, SseSerializer serializer);

  @protected
  void sse_encode_list_dicom_dir_entry(
    List<DicomDirEntry> self,
    SseSerializer serializer,
  );

  @protected
  void sse_encode_list_dicom_directory_entry(
    List<DicomDirectoryEntry> self,
    SseSerializer serializer,
  );

  @protected
  void sse_encode_list_dicom_instance(
    List<DicomInstance> self,
    SseSerializer serializer,
  );

  @protected
  void sse_encode_list_dicom_patient(
    List<DicomPatient> self,
    SseSerializer serializer,
  );

  @protected
  void sse_encode_list_dicom_series(
    List<DicomSeries> self,
    SseSerializer serializer,
  );

  @protected
  void sse_encode_list_dicom_slice(
    List<DicomSlice> self,
    SseSerializer serializer,
  );

  @protected
  void sse_encode_list_dicom_study(
    List<DicomStudy> self,
    SseSerializer serializer,
  );

  @protected
  void sse_encode_list_dicom_tag(List<DicomTag> self, SseSerializer serializer);

  @protected
  void sse_encode_list_prim_f_32_strict(
    Float32List self,
    SseSerializer serializer,
  );

  @protected
  void sse_encode_list_prim_f_64_strict(
    Float64List self,
    SseSerializer serializer,
  );

  @protected
  void sse_encode_list_prim_i_32_strict(
    Int32List self,
    SseSerializer serializer,
  );

  @protected
  void sse_encode_list_prim_u_8_loose(List<int> self, SseSerializer serializer);

  @protected
  void sse_encode_list_prim_u_8_strict(
    Uint8List self,
    SseSerializer serializer,
  );

  @protected
  void sse_encode_list_record_string_dicom_tag(
    List<(String, DicomTag)> self,
    SseSerializer serializer,
  );

  @protected
  void sse_encode_list_record_string_dicom_value_type(
    List<(String, DicomValueType)> self,
    SseSerializer serializer,
  );

  @protected
  void sse_encode_list_record_string_map_string_dicom_tag(
    List<(String, Map<String, DicomTag>)> self,
    SseSerializer serializer,
  );

  @protected
  void sse_encode_opt_String(String? self, SseSerializer serializer);

  @protected
  void sse_encode_opt_box_autoadd_f_64(double? self, SseSerializer serializer);

  @protected
  void sse_encode_opt_box_autoadd_i_32(int? self, SseSerializer serializer);

  @protected
  void sse_encode_opt_box_autoadd_u_16(int? self, SseSerializer serializer);

  @protected
  void sse_encode_opt_box_autoadd_u_32(int? self, SseSerializer serializer);

  @protected
  void sse_encode_opt_list_prim_f_64_strict(
    Float64List? self,
    SseSerializer serializer,
  );

  @protected
  void sse_encode_record_f_64_f_64_f_64(
    (double, double, double) self,
    SseSerializer serializer,
  );

  @protected
  void sse_encode_record_string_dicom_tag(
    (String, DicomTag) self,
    SseSerializer serializer,
  );

  @protected
  void sse_encode_record_string_dicom_value_type(
    (String, DicomValueType) self,
    SseSerializer serializer,
  );

  @protected
  void sse_encode_record_string_map_string_dicom_tag(
    (String, Map<String, DicomTag>) self,
    SseSerializer serializer,
  );

  @protected
  void sse_encode_u_16(int self, SseSerializer serializer);

  @protected
  void sse_encode_u_32(int self, SseSerializer serializer);

  @protected
  void sse_encode_u_8(int self, SseSerializer serializer);

  @protected
  void sse_encode_unit(void self, SseSerializer serializer);

  @protected
  void sse_encode_usize(BigInt self, SseSerializer serializer);
}

// Section: wire_class

class RustLibWire implements BaseWire {
  factory RustLibWire.fromExternalLibrary(ExternalLibrary lib) =>
      RustLibWire(lib.ffiDynamicLibrary);

  /// Holds the symbol lookup function.
  final ffi.Pointer<T> Function<T extends ffi.NativeType>(String symbolName)
  _lookup;

  /// The symbols are looked up in [dynamicLibrary].
  RustLibWire(ffi.DynamicLibrary dynamicLibrary)
    : _lookup = dynamicLibrary.lookup;

  void
  rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEl(
    ffi.Pointer<ffi.Void> ptr,
  ) {
    return _rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEl(
      ptr,
    );
  }

  late final _rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerElPtr =
      _lookup<ffi.NativeFunction<ffi.Void Function(ffi.Pointer<ffi.Void>)>>(
        'frbgen_dicom_rs_rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEl',
      );
  late final _rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEl =
      _rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerElPtr
          .asFunction<void Function(ffi.Pointer<ffi.Void>)>();

  void
  rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEl(
    ffi.Pointer<ffi.Void> ptr,
  ) {
    return _rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEl(
      ptr,
    );
  }

  late final _rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerElPtr =
      _lookup<ffi.NativeFunction<ffi.Void Function(ffi.Pointer<ffi.Void>)>>(
        'frbgen_dicom_rs_rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEl',
      );
  late final _rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEl =
      _rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerElPtr
          .asFunction<void Function(ffi.Pointer<ffi.Void>)>();
}
