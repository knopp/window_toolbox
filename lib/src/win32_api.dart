// ignore_for_file: constant_identifier_names, non_constant_identifier_names

@DefaultAsset('package:win32/win32.dart')
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

(int, int) splitLParam(int lParam) {
  final x = lParam & 0xFFFF;
  final y = (lParam >> 16) & 0xFFFF;
  return (x, y);
}

int makeLParam(int x, int y) => (y << 16) | (x & 0xFFFF);

(int, int) screenToClient(HWND hwnd, int screenX, int screenY) {
  final point = malloc<POINT>();
  point.ref.x = screenX;
  point.ref.y = screenY;
  ScreenToClient(hwnd, point);
  final result = (point.ref.x, point.ref.y);
  malloc.free(point);
  return result;
}

final class TRACKMOUSEEVENT extends Struct {
  @Uint32()
  external int cbSize;

  @Uint32()
  external int dwFlags;

  external Pointer _hwndTrack;

  HWND get hwndTrack => HWND(_hwndTrack);
  set hwndTrack(HWND value) => _hwndTrack = _hwndTrack = value;

  @Uint32()
  external int dwHoverTime;
}

const TME_HOVER = 0x00000001;
const TME_LEAVE = 0x00000002;
const TME_CANCEL = 0x80000000;
const TME_NONCLIENT = 0x00000010;

const WM_NCMOUSELEAVE = 0x02A2;
const WM_MOUSELEAVE = 0x02A3;

@Native<Int32 Function(Pointer<TRACKMOUSEEVENT>)>(
  isLeaf: true,
  symbol: 'TrackMouseEvent',
)
external int _TrackMouseEvent(Pointer<TRACKMOUSEEVENT> lpEventTrack);

bool TrackMouseEvent(Pointer<TRACKMOUSEEVENT> lpEventTrack) =>
    _TrackMouseEvent(lpEventTrack) != FALSE;

final int Function(Pointer<Void>) GetDpiForWindow = DynamicLibrary.process()
    .lookupFunction<
      Uint32 Function(Pointer<Void>),
      int Function(Pointer<Void>)
    >('FlutterDesktopGetDpiForHWND');
