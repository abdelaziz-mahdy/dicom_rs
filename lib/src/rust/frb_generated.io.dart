// This file is automatically generated, so please do not edit it.
// @generated by `flutter_rust_bridge`@ 2.8.0.

// ignore_for_file: unused_import, unused_element, unnecessary_import, duplicate_ignore, invalid_use_of_internal_member, annotate_overrides, non_constant_identifier_names, curly_braces_in_flow_control_structures, prefer_const_literals_to_create_immutables, unused_field

import 'api/dicom_rs.dart';
import 'api/simple.dart';
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

  @protected
  String dco_decode_String(dynamic raw);

  @protected
  bool dco_decode_bool(dynamic raw);

  @protected
  DicomHandler dco_decode_box_autoadd_dicom_handler(dynamic raw);

  @protected
  int dco_decode_box_autoadd_i_32(dynamic raw);

  @protected
  int dco_decode_box_autoadd_u_16(dynamic raw);

  @protected
  DicomDirectoryEntry dco_decode_dicom_directory_entry(dynamic raw);

  @protected
  DicomFile dco_decode_dicom_file(dynamic raw);

  @protected
  DicomHandler dco_decode_dicom_handler(dynamic raw);

  @protected
  DicomImage dco_decode_dicom_image(dynamic raw);

  @protected
  DicomMetadata dco_decode_dicom_metadata(dynamic raw);

  @protected
  DicomTag dco_decode_dicom_tag(dynamic raw);

  @protected
  DicomValueType dco_decode_dicom_value_type(dynamic raw);

  @protected
  double dco_decode_f_32(dynamic raw);

  @protected
  int dco_decode_i_32(dynamic raw);

  @protected
  List<String> dco_decode_list_String(dynamic raw);

  @protected
  List<DicomDirectoryEntry> dco_decode_list_dicom_directory_entry(dynamic raw);

  @protected
  List<DicomTag> dco_decode_list_dicom_tag(dynamic raw);

  @protected
  Float32List dco_decode_list_prim_f_32_strict(dynamic raw);

  @protected
  Int32List dco_decode_list_prim_i_32_strict(dynamic raw);

  @protected
  Uint8List dco_decode_list_prim_u_8_strict(dynamic raw);

  @protected
  String? dco_decode_opt_String(dynamic raw);

  @protected
  int? dco_decode_opt_box_autoadd_i_32(dynamic raw);

  @protected
  int? dco_decode_opt_box_autoadd_u_16(dynamic raw);

  @protected
  int dco_decode_u_16(dynamic raw);

  @protected
  int dco_decode_u_32(dynamic raw);

  @protected
  int dco_decode_u_8(dynamic raw);

  @protected
  void dco_decode_unit(dynamic raw);

  @protected
  String sse_decode_String(SseDeserializer deserializer);

  @protected
  bool sse_decode_bool(SseDeserializer deserializer);

  @protected
  DicomHandler sse_decode_box_autoadd_dicom_handler(
    SseDeserializer deserializer,
  );

  @protected
  int sse_decode_box_autoadd_i_32(SseDeserializer deserializer);

  @protected
  int sse_decode_box_autoadd_u_16(SseDeserializer deserializer);

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
  DicomMetadata sse_decode_dicom_metadata(SseDeserializer deserializer);

  @protected
  DicomTag sse_decode_dicom_tag(SseDeserializer deserializer);

  @protected
  DicomValueType sse_decode_dicom_value_type(SseDeserializer deserializer);

  @protected
  double sse_decode_f_32(SseDeserializer deserializer);

  @protected
  int sse_decode_i_32(SseDeserializer deserializer);

  @protected
  List<String> sse_decode_list_String(SseDeserializer deserializer);

  @protected
  List<DicomDirectoryEntry> sse_decode_list_dicom_directory_entry(
    SseDeserializer deserializer,
  );

  @protected
  List<DicomTag> sse_decode_list_dicom_tag(SseDeserializer deserializer);

  @protected
  Float32List sse_decode_list_prim_f_32_strict(SseDeserializer deserializer);

  @protected
  Int32List sse_decode_list_prim_i_32_strict(SseDeserializer deserializer);

  @protected
  Uint8List sse_decode_list_prim_u_8_strict(SseDeserializer deserializer);

  @protected
  String? sse_decode_opt_String(SseDeserializer deserializer);

  @protected
  int? sse_decode_opt_box_autoadd_i_32(SseDeserializer deserializer);

  @protected
  int? sse_decode_opt_box_autoadd_u_16(SseDeserializer deserializer);

  @protected
  int sse_decode_u_16(SseDeserializer deserializer);

  @protected
  int sse_decode_u_32(SseDeserializer deserializer);

  @protected
  int sse_decode_u_8(SseDeserializer deserializer);

  @protected
  void sse_decode_unit(SseDeserializer deserializer);

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
  void sse_encode_box_autoadd_i_32(int self, SseSerializer serializer);

  @protected
  void sse_encode_box_autoadd_u_16(int self, SseSerializer serializer);

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
  void sse_encode_dicom_metadata(DicomMetadata self, SseSerializer serializer);

  @protected
  void sse_encode_dicom_tag(DicomTag self, SseSerializer serializer);

  @protected
  void sse_encode_dicom_value_type(
    DicomValueType self,
    SseSerializer serializer,
  );

  @protected
  void sse_encode_f_32(double self, SseSerializer serializer);

  @protected
  void sse_encode_i_32(int self, SseSerializer serializer);

  @protected
  void sse_encode_list_String(List<String> self, SseSerializer serializer);

  @protected
  void sse_encode_list_dicom_directory_entry(
    List<DicomDirectoryEntry> self,
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
  void sse_encode_list_prim_i_32_strict(
    Int32List self,
    SseSerializer serializer,
  );

  @protected
  void sse_encode_list_prim_u_8_strict(
    Uint8List self,
    SseSerializer serializer,
  );

  @protected
  void sse_encode_opt_String(String? self, SseSerializer serializer);

  @protected
  void sse_encode_opt_box_autoadd_i_32(int? self, SseSerializer serializer);

  @protected
  void sse_encode_opt_box_autoadd_u_16(int? self, SseSerializer serializer);

  @protected
  void sse_encode_u_16(int self, SseSerializer serializer);

  @protected
  void sse_encode_u_32(int self, SseSerializer serializer);

  @protected
  void sse_encode_u_8(int self, SseSerializer serializer);

  @protected
  void sse_encode_unit(void self, SseSerializer serializer);
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
}
