(*
 * Copyright (c) 2014-2015 David Sheets <sheets@alum.mit.edu>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 *)

module Type = Unix_sys_stat_types.C(Unix_sys_stat_types_detected)
module C = Unix_sys_stat_bindings.C(Unix_sys_stat_generated)

module File_kind = struct
  open Sys_stat.File_kind

  let host =
    let defns = Type.File_kind.({
      mask   = s_ifmt;
      dir    = s_ifdir;
      chr    = s_ifchr;
      blk    = s_ifblk;
      reg    = s_ifreg;
      fifo   = s_ififo;
      lnk    = s_iflnk;
      sock   = s_ifsock;
    }) in
    Host.of_defns defns

  let to_unix = Unix.(function
    | DIR  -> S_DIR
    | CHR  -> S_CHR
    | BLK  -> S_BLK
    | REG  -> S_REG
    | FIFO -> S_FIFO
    | LNK  -> S_LNK
    | SOCK -> S_SOCK
  )

  let of_unix = Unix.(function
    | S_DIR  -> DIR
    | S_CHR  -> CHR
    | S_BLK  -> BLK
    | S_REG  -> REG
    | S_FIFO -> FIFO
    | S_LNK  -> LNK
    | S_SOCK -> SOCK
  )
end

module File_perm = struct
  open Sys_stat.File_perm

  let host =
    let open Type.File_perm in
    let rwxu = s_irwxu in
    let rwxg = s_irwxg in
    let rwxo = s_irwxo in
    let access_mask = rwxu lor rwxg lor rwxo in
    let suid = s_isuid in
    let sgid = s_isgid in
    let svtx = s_isvtx in
    let full_mask = access_mask lor suid lor sgid lor svtx in
    let defns = {
      access_mask;
      full_mask;
      rwxu;
      rwxg;
      rwxo;
      suid;
      sgid;
      svtx;
    } in
    Host.of_defns defns

end

module Mode = struct
  let host = Sys_stat.Mode.Host.({
    file_kind = File_kind.host;
    file_perm = File_perm.host;
  })
end

let host = Sys_stat.Host.({
  file_kind = File_kind.host;
  file_perm = File_perm.host;
  mode = Mode.host;
})

module Stat = struct
  open Ctypes
  open PosixTypes
  open Unsigned
  open Type.Stat

  type t = Type.Stat.t structure

  let dev s       = getf s st_dev
  let ino s       = getf s st_ino
  let nlink s     = getf s st_nlink
  let mode s      = getf s st_mode
  let uid s       = getf s st_uid
  let gid s       = getf s st_gid
  let rdev s      = getf s st_rdev
  let size s      = getf s st_size
  let blocks s    = getf s st_blocks
  let atime s     = getf s st_atime
  let mtime s     = getf s st_mtime
  let ctime s     = getf s st_ctime

  let to_unix ~host t =
    let (st_kind, st_perm) = Sys_stat.Mode.(
      of_code_exn ~host:host.Sys_stat.Host.mode (Mode.to_int (mode t))
    ) in
    Posix_types.(Unix.LargeFile.({
      st_dev   = Dev.to_int (dev t);
      st_ino   = Ino.to_int (ino t);
      st_kind  = File_kind.to_unix st_kind;
      st_perm;
      st_nlink = Nlink.to_int (nlink t);
      st_uid   = Uid.to_int (uid t);
      st_gid   = Gid.to_int (gid t);
      st_rdev  = Dev.to_int (rdev t);
      st_size  = Off.to_int64 (size t);
      st_atime = float_of_int (Time.to_int (atime t));
      st_mtime = float_of_int (Time.to_int (mtime t));
      st_ctime = float_of_int (Time.to_int (ctime t));
    }))

end

let mkdir name mode =
  Errno_unix.raise_on_errno ~call:"mkdir" ~label:name (fun () ->
    let mode = Posix_types.Mode.of_int (Sys_stat.Mode.to_code ~host:Mode.host mode) in
    if C.mkdir name mode <> 0
    then None
    else Some ()
  )

let mknod name mode ~dev =
  Errno_unix.raise_on_errno ~call:"mknod" ~label:name (fun () ->
    let dev = PosixTypes.Dev.of_int dev in
    let mode = PosixTypes.Mode.of_int (Sys_stat.Mode.to_code ~host:Mode.host mode) in
    if C.mknod name mode dev <> 0
    then None
    else Some ()
  )

let stat name =
  Errno_unix.raise_on_errno ~call:"stat" ~label:name (fun () ->
    let stat = Ctypes.make Type.Stat.t in
    if C.stat name (Ctypes.addr stat) <> 0
    then None
    else Some stat
  )

let lstat name =
  Errno_unix.raise_on_errno ~call:"lstat" ~label:name (fun () ->
    let stat = Ctypes.make Type.Stat.t in
    if C.lstat name (Ctypes.addr stat) <> 0
    then None
    else Some stat
  )


let fstat fd =
  Errno_unix.raise_on_errno ~call:"fstat" (fun () ->
    let stat = Ctypes.make Type.Stat.t in
    if C.fstat (Unix_representations.int_of_file_descr fd) (Ctypes.addr stat) <> 0
    then None
    else Some stat
  )

let chmod name mode =
  Errno_unix.raise_on_errno ~call:"chmod" ~label:name (fun () ->
    let mode = Posix_types.Mode.of_int (Sys_stat.Mode.to_code ~host:Mode.host mode) in
    if C.chmod name mode <> 0
    then None
    else Some ()
  )

(*
let fchmod fd mode =
  Errno_unix.raise_on_errno ~call:"fchmod" (fun () ->
    (*let mode = Int32.of_int (Sys_stat.Mode.to_code ~host:Mode.host mode) in*)
    let mode = Ctypes.(coerce uint32_t PosixTypes.mode_t Unsigned.UInt32.zero) in
    ignore (C.fchmod (Fd_send_recv.int_of_fd fd) mode)
  )
*)
