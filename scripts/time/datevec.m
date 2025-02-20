########################################################################
##
## Copyright (C) 2000-2023 The Octave Project Developers
##
## See the file COPYRIGHT.md in the top-level directory of this
## distribution or <https://octave.org/copyright/>.
##
## This file is part of Octave.
##
## Octave is free software: you can redistribute it and/or modify it
## under the terms of the GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.
##
## Octave is distributed in the hope that it will be useful, but
## WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with Octave; see the file COPYING.  If not, see
## <https://www.gnu.org/licenses/>.
##
########################################################################

## -*- texinfo -*-
## @deftypefn  {} {@var{v} =} datevec (@var{date})
## @deftypefnx {} {@var{v} =} datevec (@var{date}, @var{f})
## @deftypefnx {} {@var{v} =} datevec (@var{date}, @var{p})
## @deftypefnx {} {@var{v} =} datevec (@var{date}, @var{f}, @var{p})
## @deftypefnx {} {[@var{y}, @var{m}, @var{d}, @var{h}, @var{mi}, @var{s}] =} datevec (@dots{})
## Convert a serial date number (@pxref{XREFdatenum,,@code{datenum}}) or date
## string (@pxref{XREFdatestr,,@code{datestr}}) into a date vector.
##
## A date vector is a row vector with six members, representing the year,
## month, day, hour, minute, and seconds respectively.
##
## Date number inputs can be either a scalar or nonscalar array.  Date string
## inputs can be either a single date string, a two-dimensional character
## array of dates with each row being an interpretable date string, or a cell
## string array of any dimension with each cell element containing a single
## interpretable date string.
##
## @var{v} is a two-dimensional array of date vectors, one date vector per
## row.  For array inputs, ordering of @var{v} is based on column major order
## of dates in @var{data}.
##
## @var{f} is the format string used to interpret date strings
## (@pxref{XREFdatestr,,@code{datestr}}).  If @var{date} is a string or a cell
## array of strings, but no format is specified, heuristics are used to guess
## the input format.  These heuristics could lead to matches that differ from
## the result a user might expect.  Additionally, this involves a relatively
## slow search through various formats.  It is always preferable to specify
## the format string @var{f} if it is known.  Formats which do not specify a
## particular time component will have the value set to zero.  Formats which
## do not specify a particular date component will default that component to
## January 1st of the current year.  Trailing characters are ignored for the
## purpose of calculating the date vector, even if the characters contain
## additional time/date information.
##
## @var{p} is the year at the start of the century to which two-digit years
## will be referenced.  If not specified, it defaults to the current year
## minus 50.
## @seealso{datenum, datestr, clock, now, date}
## @end deftypefn

## Algorithm: Peter Baum (http://vsg.cape.com/~pbaum/date/date0.htm)

## The function __date_str2vec__ is based on datesplit by Bill Denney.

function [y, m, d, h, mi, s] = datevec (date, f = [], p = [])

  persistent std_formats nfmt;

  if (isempty (std_formats))
    std_formats = cell ();
    nfmt = 0;
    ## These formats are specified by Matlab documentation to be parsed
    ## The '# XX' refers to the datestr numerical format code
    std_formats{++nfmt} = "dd-mmm-yyyy HH:MM:SS";   # 0
    std_formats{++nfmt} = "dd-mmm-yyyy";            # 1
    std_formats{++nfmt} = "mm/dd/yy";               # 2
    std_formats{++nfmt} = "mm/dd";                  # 6
    std_formats{++nfmt} = "HH:MM:SS";               # 13
    std_formats{++nfmt} = "HH:MM:SS PM";            # 14
    std_formats{++nfmt} = "HH:MM";                  # 15
    std_formats{++nfmt} = "HH:MM PM";               # 16
    std_formats{++nfmt} = "mm/dd/yyyy";             # 23

    ## These formats are undocumented but parsed by Matlab
    std_formats{++nfmt} = "mmmyy";                  # 12
    std_formats{++nfmt} = "mmm.dd,yyyy HH:MM:SS";   # 21
    std_formats{++nfmt} = "mmm.dd,yyyy";            # 22
    std_formats{++nfmt} = "yyyy/mm/dd";             # 26
    std_formats{++nfmt} = "yyyy-mm-dd";             # 29
    std_formats{++nfmt} = "yyyy-mm-dd HH:MM:SS";    # 31

    ## These are other formats that Octave tries
    std_formats{++nfmt} = "mmm-dd-yyyy HH:MM:SS";
    std_formats{++nfmt} = "mmm-dd-yyyy";
    std_formats{++nfmt} = "dd mmm yyyy HH:MM:SS";
    std_formats{++nfmt} = "dd mmm yyyy";
    std_formats{++nfmt} = "mmm dd yyyy HH:MM:SS";
    std_formats{++nfmt} = "mmm dd yyyy";
    std_formats{++nfmt} = "dd.mmm.yyyy HH:MM:SS";
    std_formats{++nfmt} = "dd.mmm.yyyy";
    std_formats{++nfmt} = "mmm.dd.yyyy HH:MM:SS";
    std_formats{++nfmt} = "mmm.dd.yyyy";
    std_formats{++nfmt} = "mm/dd/yyyy HH:MM";

    ## These are ISO 8601 conform formats used in several SW
    std_formats{++nfmt} = "yyyy";
    std_formats{++nfmt} = "yyyy-mm";
    std_formats{++nfmt} = "yyyy-mm-ddTHH:MM:SSZ";
    std_formats{++nfmt} = "yyyy-mm-ddTHH:MM:SS.FFFZ";
  endif

  if (nargin < 1)
    print_usage ();
  endif

  if (ischar (date))
    date = cellstr (date);
  endif

  if (isnumeric (f))
    p = f;
    f = [];
  endif

  if (isempty (f))
    f = -1;
  endif

  if (isempty (p))
    p = (localtime (time ())).year + 1900 - 50;
  endif

  do_resize = false;

  if (iscell (date))

    nd = numel (date);

    y = m = d = h = mi = s = zeros (nd, 1);

    if (f == -1)
      for k = 1:nd
        found = false;
        for l = 1:nfmt
          [f, rY, ry, fy, fm, fd, fh, fmi, fs] = ...
            __date_vfmt2sfmt__ (std_formats{l});
          [found y(k) m(k) d(k) h(k) mi(k) s(k)] = ...
            __date_str2vec__ (date{k}, p, f, rY, ry, fy, fm, fd, fh, fmi, ...
                              fs, true);
          if (found)
            break;
          endif
        endfor
        if (! found)
          error ("datevec: none of the standard formats match the DATE string");
        endif
      endfor
    else
      ## Decipher the format string just once for speed.
      [f, rY, ry, fy, fm, fd, fh, fmi, fs] = __date_vfmt2sfmt__ (f);
      for k = 1:nd
        [found y(k) m(k) d(k) h(k) mi(k) s(k)] = ...
          __date_str2vec__ (date{k}, p, f, rY, ry, fy, fm, fd, fh, fmi, ...
                            fs, false);
        if (! found)
          error ("datevec: DATE not parsed correctly with given format");
        endif
      endfor
    endif

  else   # datenum input

    if (! iscolumn (date))
      date_sz = size (date);
      do_resize = true;
    endif
    date = date(:);

    ## Move day 0 from midnight -0001-12-31 to midnight 0000-3-1
    z = double (floor (date) - 60);
    ## Calculate number of centuries; K1 = 0.25 is to avoid rounding problems.
    a = floor ((z - 0.25) / 36524.25);
    ## Days within century; K2 = 0.25 is to avoid rounding problems.
    b = z - 0.25 + a - floor (a / 4);
    ## Calculate the year (year starts on March 1).
    y = floor (b / 365.25);
    ## Calculate day in year.
    c = fix (b - floor (365.25 * y)) + 1;
    ## Calculate month in year.
    m = fix ((5 * c + 456) / 153);
    d = c - fix ((153 * m - 457) / 5);
    ## Move to Jan 1 as start of year.
    ++y(m > 12);
    m(m > 12) -= 12;

    ## Convert hour-minute-seconds.  Attempt to account for precision of
    ## datenum format.

    fracd = date - floor (date);
    tmps = abs (eps*86400*date);
    tmps(tmps == 0) = 1;
    srnd = 2 .^ floor (- log2 (tmps));
    s = round (86400 * fracd .* srnd) ./ srnd;
    h = floor (s / 3600);
    s -= 3600 * h;
    mi = floor (s / 60);
    s -= 60 * mi;

  endif

  if (nargout <= 1)
    y = [y, m, d, h, mi, s];
  elseif (do_resize)
    y = reshape (y, date_sz);
    m = reshape (m, date_sz);
    d = reshape (d, date_sz);
    h = reshape (h, date_sz);
    mi = reshape (mi, date_sz);
    s = reshape (s, date_sz);
  endif

endfunction

function [f, rY, ry, fy, fm, fd, fh, fmi, fs] = __date_vfmt2sfmt__ (f)

  original_f = f;   # Store for error messages.

  if (any (strchr (f, "hsfYD", 1)))
    warning ("Octave:datevec:date-format-spec", ...
             ["datevec: Format specifiers for dates should be lower case,", ...
              " format specifiers for time should be upper case. ", ...
              " Possible issue with 'm' (month) and 'M' (minutes)?"]);
  endif

  ## Play safe with percent signs.
  f = strrep (f, "%", "%%");

  if (! isempty (strfind (f, "PM")) || ! isempty (strfind (f, "AM")))
    ampm = true;
  else
    ampm = false;
  endif

  ## Date part.
  f = regexprep (f, '[Yy][Yy][Yy][Yy]', "%Y");
  f = regexprep (f, '[Yy][Yy]', "%y");
  f = strrep (f, "mmmm", "%B");
  f = strrep (f, "mmm", "%b");
  f = strrep (f, "mm", "%m");
  f = regexprep (f, '[Dd][Dd][Dd][Dd]', "%A");
  f = regexprep (f, '[Dd][Dd][Dd]', "%a");
  f = regexprep (f, '[Dd][Dd]', "%d");

  ## Time part.
  if (ampm)
    f = strrep (f, "HH", "%I");
    f = strrep (f, "PM", "%p");
    f = strrep (f, "AM", "%p");
  else
    f = strrep (f, "HH", "%H");
  endif
  f = strrep (f, "MM", "%M");
  f = regexprep (f, '[Ss][Ss]', "%S");

  ## Check for conflicting or repeated fields.
  ## Only warn, not error, if we may be confused by an original '%'s.
  if (index (original_f, "%"))
    err_or_warn = @warning;
  else
    err_or_warn = @error;
  endif

  if (numel (strfind (f, "%Y")) + numel (strfind (f, "%y")) > 1)
    err_or_warn ("datevec: multiple year specifiers in %s", original_f);
  elseif (numel (strfind (f, "%m")) + numel (strfind (f, "%b"))
          + numel (strfind (f, "%B")) > 1)
    err_or_warn ("datevec: multiple month specifiers in %s", original_f);
  elseif (numel (strfind (f, "%d")) > 1)
    err_or_warn ("datevec: multiple day specifiers in %s", original_f);
  elseif (numel (strfind (f, "%a"))+ numel (strfind (f, "%A")) > 1)
    err_or_warn ("datevec: multiple day of week specifiers in %s", original_f);
  elseif (numel (strfind (f, "%H")) + numel (strfind (f, "%I")) > 1)
    err_or_warn ("datevec: multiple hour specifiers in %s", original_f);
  elseif (numel (strfind (f, "%M")) > 1)
    err_or_warn ("datevec: multiple minute specifiers in %s", original_f);
  elseif (numel (strfind (f, "%S")) > 1)
    err_or_warn ("datevec: multiple second specifiers in %s", original_f);
  endif

  rY = rindex (f, "%Y");
  ry = rindex (f, "%y");

  ## Check whether we need to give default values.
  ## Possible error when string contains "%%".
  fy = rY || ry;
  fm = index (f, "%m") || index (f, "%b") || index (f, "%B");
  fd = index (f, "%d") || index (f, "%a") || index (f, "%A");
  fh = index (f, "%H") || index (f, "%I");
  fmi = index (f, "%M");
  fs = index (f, "%S");

endfunction

function [found, y, m, d, h, mi, s] = __date_str2vec__ (ds, p, f, rY, ry, fy, fm, fd, fh, fmi, fs, exact_match)

  ## Local time zone is irrelevant, and potentially dangerous, when using
  ## strptime to simply convert a string into a broken down struct tm.
  ## Set and restore TZ so time is parsed exactly as-is. See bug #36954.
  TZ_orig = getenv ("TZ");
  unwind_protect
    setenv ("TZ", "UTC0");

    idx = strfind (f, "FFF");
    if (! isempty (idx))
      ## Kludge to handle FFF millisecond format since strptime does not.

      ## Find location of FFF in ds.
      ## Might not match idx because of things like yyyy -> %y.
      [~, nc] = strptime (ds, f(1:idx-1));

      if (! isempty (nc) && nc != 0)
        msec = ds(nc:min (nc+2,end));  # pull 3-digit fractional seconds.
        msec_idx = find (! isdigit (msec), 1);

        if (! isempty (msec_idx))  # non-digits in msec
          msec = msec(1:msec_idx-1);
          msec(end+1:3) = "0";  # pad msec with trailing zeros
          ds = [ds(1:(nc-1)), msec, ds((nc-1)+msec_idx:end)];  # zero pad ds
        elseif (numel (msec) < 3)  # less than three digits in msec
          m_len = numel (msec);
          msec(end+1:3) = "0";  # pad msec with trailing zeros
          ds = [ds(1:(nc-1)), msec, ds(nc+m_len:end)];  # zero pad ds as well
        endif

        ## replace FFF with digits to guarantee match in strptime.
        f(idx:idx+2) = msec;

        if (nc > 0)
          [tm, nc] = strptime (ds, f);
          tm.usec = 1000 * str2double (msec);
        endif
      endif

    else
      [tm, nc] = strptime (ds, f);
    endif
  unwind_protect_cleanup
    if (isempty (TZ_orig))
      unsetenv ("TZ");
    else
      setenv ("TZ", TZ_orig);
    endif
  end_unwind_protect

  ## Require an exact match unless the user supplied a format to use, then use
  ## that format as long as it matches the start of the string and ignore any
  ## trailing characters.
  if ((! exact_match && nc > 0) || (nc == columns (ds) + 1))
    found = true;
    y = tm.year + 1900; m = tm.mon + 1; d = tm.mday;
    h = tm.hour; mi = tm.min; s = tm.sec + tm.usec / 1e6;
    if (rY < ry)
      if (y > 1999)
        y -= 2000;
      else
        y -= 1900;
      endif
      y += p - mod (p, 100);
      if (y < p)
        y += 100;
      endif
    endif
    if (! fy && ! fm && ! fd)
      tmp = localtime (time ());
      ## default is January 1st of current year
      y = tmp.year + 1900;
      m = 1;
      d = 1;
    elseif (! fy && fm && fd)
      tmp = localtime (time ());
      y = tmp.year + 1900;
    elseif (fy && fm && ! fd)
      d = 1;
    endif
    if (! fh && ! fmi && ! fs)
      h = mi = s = 0;
    elseif (fh && fmi && ! fs)
      s = 0;
    endif
  else
    y = m = d = h = mi = s = 0;
    found = false;
  endif

endfunction


%!demo
%! ## Current date and time
%! datevec (now ())

%!shared yr
%! yr = datevec (now)(1);  # Some tests could fail around midnight!
## tests for standard formats: 0, 1, 2, 6, 13, 14, 15, 16, 23
%!assert (datevec ("07-Sep-2000 15:38:09"), [2000,9,7,15,38,9])
%!assert (datevec ("07-Sep-2000"), [2000,9,7,0,0,0])
%!assert (datevec ("09/07/00"), [2000,9,7,0,0,0])
%!assert (datevec ("09/13"), [yr,9,13,0,0,0])
%!assert (datevec ("15:38:09"), [yr,1,1,15,38,9])
%!assert (datevec ("3:38:09 PM"), [yr,1,1,15,38,9])
%!assert (datevec ("15:38"), [yr,1,1,15,38,0])
%!assert (datevec ("03:38 PM"), [yr,1,1,15,38,0])
%!assert (datevec ("03/13/1962"), [1962,3,13,0,0,0])

## Test millisecond format FFF
%!assert (datevec ("15:38:21.2", "HH:MM:SS.FFF"), [yr,1,1,15,38,21.2])
%!assert (datevec ("15:38:21.25", "HH:MM:SS.FFF"), [yr,1,1,15,38,21.25])
%!assert (datevec ("15:38:21.251", "HH:MM:SS.FFF"), [yr,1,1,15,38,21.251])

## Test millisecond format FFF with AM/PM, and 1,2, or 3 FFF digits
%!assert (datevec ("06/01/2015 3:07:12.102 PM", "mm/dd/yyyy HH:MM:SS.FFF PM"),
%!        [2015,6,1,15,7,12.102])
%!assert (datevec ("06/01/2015 11:07:12.102 PM", "mm/dd/yyyy HH:MM:SS.FFF PM"),
%!        [2015,6,1,23,7,12.102])
%!assert (datevec ("06/01/2015 3:07:12.102 AM", "mm/dd/yyyy HH:MM:SS.FFF PM"),
%!        [2015,6,1,3,7,12.102])
%!assert (datevec ("06/01/2015 11:07:12.102 AM", "mm/dd/yyyy HH:MM:SS.FFF PM"),
%!        [2015,6,1,11,7,12.102])
%!assert (datevec ("06/01/2015 3:07:12.1 PM", "mm/dd/yyyy HH:MM:SS.FFF PM"),
%!        [2015,6,1,15,7,12.1])
%!assert (datevec ("06/01/2015 3:07:12.12 AM", "mm/dd/yyyy HH:MM:SS.FFF PM"),
%!        [2015,6,1,3,7,12.12])
%!assert (datevec ("06/01/2015 3:07:12.12 PM", "mm/dd/yyyy HH:MM:SS.FFF PM"),
%!        [2015,6,1,15,7,12.12])

## Test ISO 8601 conform formats
%!assert (datevec ("1998"), [1998, 1, 0, 0, 0, 0]);
%!assert (datevec ("1998-07"), [1998, 7, 1, 0, 0, 0]);
%!assert (datevec ("1998-07-19T15:03:47Z"), [1998, 7, 19, 15, 3, 47]);
%!assert (datevec ("1998-07-19T15:03:47.219Z"), [1998, 7, 19, 15, 3, 47.219]);

## Test structure of return value
%!test <*42334>
%! [~, ~, d] = datevec ([1 2; 3 4]);
%! assert (d, [1 2; 3 4]);

## Other tests
%!assert (datenum (datevec ([-1e4:1e4])), [-1e4:1e4]')
%!test
%! t = linspace (-2e5, 2e5, 10993);
%! assert (all (abs (datenum (datevec (t)) - t') < 1e-5));
%!assert (double (datevec (int64 (datenum ([2014 6 1])))),
%!        datevec (datenum ([2014 6 1])))
%!assert (double (datevec (int64 (datenum ([2014 6 18])))),
%!        datevec (datenum ([2014 6 18])))

## Test parsing of date strings that fall within daylight saving transition
%!testif ; isunix () <*36954>
%! zones = { "UTC0"                                 ...
%!           "EST+5EDT,M3.2.0/2,M11.1.0/2"          ... America/New_York
%!           "CET-1CEST,M3.5.0/2,M10.5.0/2"         ... Europe/Berlin
%!           "CLT+4CLST,M8.2.0/0,M5.2.0/0"          ... America/Santiago
%!           "LHST-10:30LHDT-11,M10.1.0/2,M4.1.0/2" ... Australia/Lord_Howe
%!           ":America/Caracas"                     ...
%!         };
%! TZ_orig = getenv ("TZ");
%! unwind_protect
%!   for i = 1:numel (zones)
%!     setenv ("TZ", zones{i});
%!     ## These specific times were chosen to test conversion during the loss
%!     ## of some amount of local time at the start of daylight saving time in
%!     ## each of the zones listed above.  We test all in each time zone to be
%!     ## exhaustive, even though each is problematic for only one of the zones.
%!     assert (datevec ("2017-03-12 02:15:00"), [2017  3 12 2 15 0]);
%!     assert (datevec ("2017-03-26 02:15:00"), [2017  3 26 2 15 0]);
%!     assert (datevec ("2017-08-13 00:15:00"), [2017  8 13 0 15 0]);
%!     assert (datevec ("2017-10-01 02:15:00"), [2017 10  1 2 15 0]);
%!     ## This tests a one-time loss of 30 minutes in Venezuela's local time
%!     assert (datevec ("2016-05-01 02:40:00"), [2016  5  1 2 40 0]);
%!   endfor
%! unwind_protect_cleanup
%!   if (isempty (TZ_orig))
%!     unsetenv ("TZ");
%!   else
%!     setenv ("TZ", TZ_orig);
%!   endif
%! end_unwind_protect

## Test matching string and ignoring trailing characters
%!test <*42241>
%! fail ("datevec ('2013-08-15 09:00:35/xyzpdq')");
%! assert (datevec ("15-Aug-2013 09:00:35.123", "dd-mmm-yyyy HH:MM:SS"), ...
%!              [2013, 8, 15, 9, 0, 35]);
%! assert (datevec ("2013-08-15 09:00:35/xyzpdq", "yyyy-mm-dd HH:MM:SS"), ...
%!              [2013, 8, 15, 9, 0, 35]);

## Test all other standard formats specified in function with/without trailing
## characters with format specified.

## 0 dd-mm-yyyy HH:MM:SS
%!assert <*42241> (datevec ("15-aug-2013 09:00:35"), [2013, 8, 15, 9, 0, 35])
%!assert <*42241> (datevec ("15-aug-2013 09:00:35", "dd-mmm-yyyy HH:MM:SS"), [2013, 8, 15, 9, 0, 35])
%!assert <*42241> (datevec ("15-aug-2013 09:00:35ABC", "dd-mmm-yyyy HH:MM:SS"), [2013, 8, 15, 9, 0, 35])

## 1 dd-mmm-yyyy
%!assert <*42241> (datevec ("15-aug-2013"), [2013, 8, 15, 0, 0, 0])
%!assert <*42241> (datevec ("15-aug-2013", "dd-mmm-yyyy"), [2013, 8, 15, 0, 0, 0])
%!assert <*42241> (datevec ("15-aug-2013 09:00:35", "dd-mmm-yyyy"), [2013, 8, 15, 0, 0, 0])
%!assert <*42241> (datevec ("15-aug-2013ABC", "dd-mmm-yyyy"), [2013, 8, 15, 0, 0, 0])

## 2 mm/dd/yy
%!assert <*42241> (datevec ("08/15/13"), [2013, 8, 15, 0, 0, 0])
%!assert <*42241> (datevec ("08/15/13", "mm/dd/yy"), [2013, 8, 15, 0, 0, 0])
%!assert <*42241> (datevec ("08/15/13 09:00:35", "mm/dd/yy"), [2013, 8, 15, 0, 0, 0])
%!assert <*42241> (datevec ("08/15/13ABC", "mm/dd/yy"), [2013, 8, 15, 0, 0, 0])

## 3 mmm
%!assert <*42241> (datevec ("Aug", "mmm"), [1900, 8, 0, 0, 0, 0])
%!assert <*42241> (datevec ("Aug 15", "mmm"), [1900, 8, 0, 0, 0, 0])
%!assert <*42241> (datevec ("AugABC", "mmm"), [1900, 8, 0, 0, 0, 0])

## 4 m datestr std format 4 -  datevec("A", "m") does not resolve

## 5 mm
%!assert <*42241> (datevec ("08"), [8, 1, 0, 0, 0, 0])
%!assert <*42241> (datevec ("08", "mm"), [1900, 8, 0, 0, 0, 0])
%!assert <*42241> (datevec ("08/15/2013", "mm"), [1900, 8, 0, 0, 0, 0])
%!assert <*42241> (datevec ("08ABC", "mm"), [1900, 8, 0, 0, 0, 0])

# 6 mm/dd
%!assert <*42241> (datevec ("08/15"), [yr, 8, 15, 0, 0, 0])
%!assert <*42241> (datevec ("08/15", "mm/dd"), [yr, 8, 15, 0, 0, 0])
%!assert <*42241> (datevec ("08/15/13", "mm/dd"), [yr, 8, 15, 0, 0, 0])
%!assert <*42241> (datevec ("08/15ABC", "mm/dd"), [yr, 8, 15, 0, 0, 0])

## 7 dd
%!assert <*42241> (datevec ("15"), [15, 1, 0, 0, 0, 0])
%!assert <*42241> (datevec ("15", "dd"), [1900, 1, 15, 0, 0, 0])
%!assert <*42241> (datevec ("15-Aug-2013", "dd"), [1900, 1, 15, 0, 0, 0])
%!assert <*42241> (datevec ("15ABC", "dd"), [1900, 1, 15, 0, 0, 0])

## 8 ddd
%!assert <*42241> (datevec ("Fri", "ddd"), [1900, 1, 0, 0, 0, 0])
%!assert <*42241> (datevec ("Fri, Aug 15 2013", "ddd"), [1900, 1, 0, 0, 0, 0])
%!assert <*42241> (datevec ("FriABC", "ddd"), [1900, 1, 0, 0, 0, 0])

## 9 d datestr std format 9 -  datevec("F", "d") does not resolve

## 10 yyyy
%!assert <*42241> (datevec ("2013"), [2013, 1, 0, 0, 0, 0])
%!assert <*42241> (datevec ("2013", "yyyy"), [2013, 1, 0, 0, 0, 0])
%!assert <*42241> (datevec ("2013/08/15", "yyyy"), [2013, 1, 0, 0, 0, 0])
%!assert <*42241> (datevec ("2013ABC", "yyyy"), [2013, 1, 0, 0, 0, 0])

## 11 yy
%!assert <*42241> (datevec ("13"), [13, 1, 0, 0, 0, 0])
%!assert <*42241> (datevec ("13", "yy"), [2013, 1, 0, 0, 0, 0])
%!assert <*42241> (datevec ("13/08/15", "yy"), [2013, 1, 0, 0, 0, 0])
%!assert <*42241> (datevec ("13ABC", "yy"), [2013, 1, 0, 0, 0, 0])

## 12 mmmyy
%!assert <*42241> (datevec ("AUG13"), [2013, 8, 1, 0, 0, 0])
%!assert <*42241> (datevec ("AUG13", "mmmyy"), [2013, 8, 1, 0, 0, 0])
%!assert <*42241> (datevec ("AUG2013", "mmmyy"), [2020, 8, 1, 0, 0, 0])
%!assert <*42241> (datevec ("AUG13ABC", "mmmyy"), [2013, 8, 1, 0, 0, 0])

## 13 HH:MM:SS
%!assert <*42241> (datevec ("09:00:35"), [yr, 1, 1, 9, 0, 35])
%!assert <*42241> (datevec ("09:00:35", "HH:MM:SS"), [yr, 1, 1, 9, 0, 35])
%!assert <*42241> (datevec ("09:00:35 AM", "HH:MM:SS"), [yr, 1, 1, 9, 0, 35])
%!assert <*42241> (datevec ("09:00:35ABC", "HH:MM:SS"), [yr, 1, 1, 9, 0, 35])

## 14 HH:MM:SS PM
%!assert <*42241> (datevec ("09:00:35 AM"), [yr, 1, 1, 9, 0, 35])
%!assert <*42241> (datevec ("09:00:35 AM", "HH:MM:SS PM"), [yr, 1, 1, 9, 0, 35])
%!assert <*42241> (datevec ("09:00:35 am", "HH:MM:SS PM"), [yr, 1, 1, 9, 0, 35])
%!assert <*42241> (datevec ("09:00:35 PM", "HH:MM:SS PM"), [yr, 1, 1, 21, 0, 35])
%!assert <*42241> (datevec ("09:00:35 AMABC", "HH:MM:SS PM"), [yr, 1, 1, 9, 0, 35])

## 15 HH:MM
%!assert <*42241> (datevec ("09:00"), [yr, 1, 1, 9, 0, 0])
%!assert <*42241> (datevec ("09:00", "HH:MM"), [yr, 1, 1, 9, 0, 0])
%!assert <*42241> (datevec ("09:00:35", "HH:MM"), [yr, 1, 1, 9, 0, 0])
%!assert <*42241> (datevec ("09:00ABC", "HH:MM"), [yr, 1, 1, 9, 0, 0])

## 16 HH:MM PM
%!assert <*42241> (datevec ("09:00 AM"), [yr, 1, 1, 9, 0, 0])
%!assert <*42241> (datevec ("09:00 AM", "HH:MM PM"), [yr, 1, 1, 9, 0, 0])
%!assert <*42241> (datevec ("09:00 PM", "HH:MM PM"), [yr, 1, 1, 21, 0, 0])
%!assert <*42241> (datevec ("09:00 AMABC", "HH:MM PM"), [yr, 1, 1, 9, 0, 0])

## 17 QQ-YY datestr std format 17 -  datevec("Q1-13", "QQ-YY") does not resolve

## 18 QQ datestr std format 18 -  datevec("Q1", "QQ") does not resolve

## 19 dd/mm
%!assert <*42241> (datevec ("15/08", "dd/mm"), [yr, 8, 15, 0, 0, 0])
%!assert <*42241> (datevec ("15/08/2023", "dd/mm"), [yr, 8, 15, 0, 0, 0])
%!assert <*42241> (datevec ("15/08ABC", "dd/mm"), [yr, 8, 15, 0, 0, 0])

## 20 dd/mm/yy
%!assert <*42241> (datevec ("15/08/13"), [15, 8, 13, 0, 0, 0])
%!assert <*42241> (datevec ("15/08/13", "dd/mm/yy"), [2013, 8, 15, 0, 0, 0])
%!assert <*42241> (datevec ("15/08/13 09:00:35", "dd/mm/yy"), [2013, 8, 15, 0, 0, 0])
%!assert <*42241> (datevec ("15/08/13ABC", "dd/mm/yy"), [2013, 8, 15, 0, 0, 0])

## 21 mmm.dd,yyyy HH:MM:SS
%!assert <*42241> (datevec ("aug.15,2013 09:00:35"), [2013, 8, 15, 9, 0, 35])
%!assert <*42241> (datevec ("aug.15,2013 09:00:35", "mmm.dd,yyyy HH:MM:SS"), [2013, 8, 15, 9, 0, 35])
%!assert <*42241> (datevec ("aug.15,2013 09:00:35 PM", "mmm.dd,yyyy HH:MM:SS"), [2013, 8, 15, 9, 0, 35])
%!assert <*42241> (datevec ("aug.15,2013 09:00:35ABC", "mmm.dd,yyyy HH:MM:SS"), [2013, 8, 15, 9, 0, 35])

## 22 mm.dd,yyyy
%!assert <*42241> (datevec ("aug.15,2013"), [2013, 8, 15, 0, 0, 0])
%!assert <*42241> (datevec ("aug.15,2013", "mmm.dd,yyyy"), [2013, 8, 15, 0, 0, 0])
%!assert <*42241> (datevec ("aug.15,2013 09:00:35", "mmm.dd,yyyy"), [2013, 8, 15, 0, 0, 0])
%!assert <*42241> (datevec ("aug.15,2013ABC", "mmm.dd,yyyy"), [2013, 8, 15, 0, 0, 0])

## 23 mm/dd/yyyy
%!assert <*42241> (datevec ("08/15/2013"), [2013, 8, 15, 0, 0, 0])
%!assert <*42241> (datevec ("08/15/2013", "mm/dd/yyyy"), [2013, 8, 15, 0, 0, 0])
%!assert <*42241> (datevec ("08/15/2013 09:00:35", "mm/dd/yyyy"), [2013, 8, 15, 0, 0, 0])
%!assert <*42241> (datevec ("08/15/2013ABC", "mm/dd/yyyy"), [2013, 8, 15, 0, 0, 0])

## 24 dd/mm/yyyy
%!assert <*42241> (datevec ("15/08/2013", "dd/mm/yyyy"), [2013, 8, 15, 0, 0, 0])
%!assert <*42241> (datevec ("15/08/2013 09:00:35", "dd/mm/yyyy"), [2013, 8, 15, 0, 0, 0])
%!assert <*42241> (datevec ("15/08/2013ABC", "dd/mm/yyyy"), [2013, 8, 15, 0, 0, 0])

## 25 yy/mm/dd
%!assert <*42241> (datevec ("13/08/15"), [13, 8, 15, 0, 0, 0])
%!assert <*42241> (datevec ("13/08/15", "yy/mm/dd"), [2013, 8, 15, 0, 0, 0])
%!assert <*42241> (datevec ("13/08/15 09:00:35", "yy/mm/dd"), [2013, 8, 15, 0, 0, 0])
%!assert <*42241> (datevec ("13/08/15ABC", "yy/mm/dd"), [2013, 8, 15, 0, 0, 0])

## 26 yyyy/mm/dd
%!assert <*42241> (datevec ("2013/08/15"), [2013, 8, 15, 0, 0, 0])
%!assert <*42241> (datevec ("2013/08/15", "yyyy/mm/dd"), [2013, 8, 15, 0, 0, 0])
%!assert <*42241> (datevec ("2013/08/15 09:00:35", "yyyy/mm/dd"), [2013, 8, 15, 0, 0, 0])
%!assert <*42241> (datevec ("2013/08/15ABC", "yyyy/mm/dd"), [2013, 8, 15, 0, 0, 0])

## 27 QQ-YYYY datestr std format 27 -  datevec("Q1-2013", "QQ-YYYY") does not resolve

## 28 mmmyyyy
%!assert <*42241> (datevec ("Aug2013"), [13, 8, 20, 0, 0, 0])
%!assert <*42241> (datevec ("Aug2013", "mmmyyyy"), [2013, 8, 1, 0, 0, 0])
%!assert <*42241> (datevec ("Aug2013 09:00:35", "mmmyyyy"), [2013, 8, 1, 0, 0, 0])
%!assert <*42241> (datevec ("Aug2013ABC", "mmmyyyy"), [2013, 8, 1, 0, 0, 0])

## 29 yyyy-mm-dd
%!assert <*42241> (datevec ("2013-08-15"), [2013, 8, 15, 0, 0, 0])
%!assert <*42241> (datevec ("2013-08-15", "yyyy-mm-dd"), [2013, 8, 15, 0, 0, 0])
%!assert <*42241> (datevec ("2013-08-15 09:00:35", "yyyy-mm-dd"), [2013, 8, 15, 0, 0, 0])
%!assert <*42241> (datevec ("2013-08-15ABC", "yyyy-mm-dd"), [2013, 8, 15, 0, 0, 0])

## 30 yyyymmddTHHMMSS
%!assert <*42241> (datevec ("20130815T090035", "yyyymmddTHHMMSS"), [2013, 8, 15, 9, 0, 35])
%!assert <*42241> (datevec ("20130815T090035", "yyyymmddTHHMMSS"), [2013, 8, 15, 9, 0, 35])
%!assert <*42241> (datevec ("20130815T090035", "yyyymmddTHHMMSS"), [2013, 8, 15, 9, 0, 35])

## 31 yyyy-mm-dd HH:MM:SS
%!assert <*42241> (datevec ("2013-08-15 09:00:35"), [2013, 8, 15, 9, 0, 35])
%!assert <*42241> (datevec ("2013-08-15 09:00:35", "yyyy-mm-dd HH:MM:SS"), [2013, 8, 15, 9, 0, 35])
%!assert <*42241> (datevec ("2013-08-15 09:00:35 PM", "yyyy-mm-dd HH:MM:SS"), [2013, 8, 15, 9, 0, 35])
%!assert <*42241> (datevec ("2013-08-15 09:00:35ABC", "yyyy-mm-dd HH:MM:SS"), [2013, 8, 15, 9, 0, 35])

## mmm-dd-yyyy HH:MM:SS
%!assert <*42241> (datevec ("Aug-15-2013 09:00:35"), [2013, 8, 15, 9, 0, 35])
%!assert <*42241> (datevec ("Aug-15-2013 09:00:35", "mmm-dd-yyyy HH:MM:SS"), [2013, 8, 15, 9, 0, 35])
%!assert <*42241> (datevec ("Aug-15-2013 09:00:35 PM", "mmm-dd-yyyy HH:MM:SS"), [2013, 8, 15, 9, 0, 35])
%!assert <*42241> (datevec ("Aug-15-2013 09:00:35ABC", "mmm-dd-yyyy HH:MM:SS"), [2013, 8, 15, 9, 0, 35])

## mmm-dd-yyyy
%!assert <*42241> (datevec ("Aug-15-2013"), [2013, 8, 15, 0, 0, 0])
%!assert <*42241> (datevec ("Aug-15-2013", "mmm-dd-yyyy"), [2013, 8, 15, 0, 0, 0])
%!assert <*42241> (datevec ("Aug-15-2013 09:00:35", "mmm-dd-yyyy"), [2013, 8, 15, 0, 0, 0])
%!assert <*42241> (datevec ("Aug-15-2013ABC", "mmm-dd-yyyy"), [2013, 8, 15, 0, 0, 0])

## dd mmm yyyy HH:MM:SS
%!assert <*42241> (datevec ("15 Aug 2013 09:00:35"), [2013, 8, 15, 9, 0, 35])
%!assert <*42241> (datevec ("15 Aug 2013 09:00:35", "dd mmm yyyy HH:MM:SS"), [2013, 8, 15, 9, 0, 35])
%!assert <*42241> (datevec ("15 Aug 2013 09:00:35 PM", "dd mmm yyyy HH:MM:SS"), [2013, 8, 15, 9, 0, 35])
%!assert <*42241> (datevec ("15 Aug 2013 09:00:35ABC", "dd mmm yyyy HH:MM:SS"), [2013, 8, 15, 9, 0, 35])

## dd mmm yyyy
%!assert <*42241> (datevec ("15 Aug 2013"), [2013, 8, 15, 0, 0, 0])
%!assert <*42241> (datevec ("15 Aug 2013", "dd mmm yyyy"), [2013, 8, 15, 0, 0, 0])
%!assert <*42241> (datevec ("15 Aug 2013 09:00:35", "dd mmm yyyy"), [2013, 8, 15, 0, 0, 0])
%!assert <*42241> (datevec ("15 Aug 2013ABC", "dd mmm yyyy"), [2013, 8, 15, 0, 0, 0])

## mmm dd yyyy HH:MM:SS
%!assert <*42241> (datevec ("Aug 15 2013 09:00:35"), [2013, 8, 15, 9, 0, 35])
%!assert <*42241> (datevec ("Aug 15 2013 09:00:35", "mmm dd yyyy HH:MM:SS"), [2013, 8, 15, 9, 0, 35])
%!assert <*42241> (datevec ("Aug 15 2013 09:00:35 PM", "mmm dd yyyy HH:MM:SS"), [2013, 8, 15, 9, 0, 35])
%!assert <*42241> (datevec ("Aug 15 2013 09:00:35ABC", "mmm dd yyyy HH:MM:SS"), [2013, 8, 15, 9, 0, 35])

## mmm dd yyyy
%!assert <*42241> (datevec ("Aug 15 2013"), [2013, 8, 15, 0, 0, 0])
%!assert <*42241> (datevec ("Aug 15 2013", "mmm dd yyyy"), [2013, 8, 15, 0, 0, 0])
%!assert <*42241> (datevec ("Aug 15 2013 09:00:35", "mmm dd yyyy"), [2013, 8, 15, 0, 0, 0])
%!assert <*42241> (datevec ("Aug 15 2013ABC", "mmm dd yyyy"), [2013, 8, 15, 0, 0, 0])

## dd.mmm.yyyy HH:MM:SS
%!assert <*42241> (datevec ("15.Aug.2013 09:00:35"), [2013, 8, 15, 9, 0, 35])
%!assert <*42241> (datevec ("15.Aug.2013 09:00:35", "dd.mmm.yyyy HH:MM:SS"), [2013, 8, 15, 9, 0, 35])
%!assert <*42241> (datevec ("15.Aug.2013 09:00:35 PM", "dd.mmm.yyyy HH:MM:SS"), [2013, 8, 15, 9, 0, 35])
%!assert <*42241> (datevec ("15.Aug.2013 09:00:35ABC", "dd.mmm.yyyy HH:MM:SS"), [2013, 8, 15, 9, 0, 35])

## dd.mmm.yyyy
%!assert <*42241> (datevec ("15.Aug.2013"), [2013, 8, 15, 0, 0, 0])
%!assert <*42241> (datevec ("15.Aug.2013", "dd.mmm.yyyy"), [2013, 8, 15, 0, 0, 0])
%!assert <*42241> (datevec ("15.Aug.2013 09:00:35", "dd.mmm.yyyy"), [2013, 8, 15, 0, 0, 0])
%!assert <*42241> (datevec ("15.Aug.2013ABC", "dd.mmm.yyyy"), [2013, 8, 15, 0, 0, 0])

## mmm.dd.yyyy HH:MM:SS
%!assert <*42241> (datevec ("Aug.15.2013 09:00:35"), [2013, 8, 15, 9, 0, 35])
%!assert <*42241> (datevec ("Aug.15.2013 09:00:35", "mmm.dd.yyyy HH:MM:SS"), [2013, 8, 15, 9, 0, 35])
%!assert <*42241> (datevec ("Aug.15.2013 09:00:35 PM", "mmm.dd.yyyy HH:MM:SS"), [2013, 8, 15, 9, 0, 35])
%!assert <*42241> (datevec ("Aug.15.2013 09:00:35ABC", "mmm.dd.yyyy HH:MM:SS"), [2013, 8, 15, 9, 0, 35])

## mmm.dd.yyyy
%!assert <*42241> (datevec ("Aug.15.2013"), [2013, 8, 15, 0, 0, 0])
%!assert <*42241> (datevec ("Aug.15.2013", "mmm.dd.yyyy"), [2013, 8, 15, 0, 0, 0])
%!assert <*42241> (datevec ("Aug.15.2013 09:00:35", "mmm.dd.yyyy"), [2013, 8, 15, 0, 0, 0])
%!assert <*42241> (datevec ("Aug.15.2013ABC", "mmm.dd.yyyy"), [2013, 8, 15, 0, 0, 0])

## mm/dd/yyyy HH:MM
%!assert <*42241> (datevec ("08/15/2013 09:00"), [2013, 8, 15, 9, 0, 0])
%!assert <*42241> (datevec ("08/15/2013 09:00", "mm/dd/yyyy HH:MM"), [2013, 8, 15, 9, 0, 0])
%!assert <*42241> (datevec ("08/15/2013 09:00:35", "mm/dd/yyyy HH:MM"), [2013, 8, 15, 9, 0, 0])
%!assert <*42241> (datevec ("08/15/2013 09:00ABC", "mm/dd/yyyy HH:MM"), [2013, 8, 15, 9, 0, 0])

## yyyy
%!assert <*42241> (datevec ("2013"), [2013, 1, 0, 0, 0, 0]) # Octave uses Jan 0 as origin
%!assert <*42241> (datevec ("2013", "yyyy"), [2013, 1, 0, 0, 0, 0])
%!assert <*42241> (datevec ("2013-08-15", "yyyy"), [2013, 1, 0, 0, 0, 0])
%!assert <*42241> (datevec ("2013ABC", "yyyy"), [2013, 1, 0, 0, 0, 0])

## yyyy-mm
%!assert <*42241> (datevec ("2013-08"), [2013, 8, 1, 0, 0, 0])
%!assert <*42241> (datevec ("2013-08", "yyyy-mm"), [2013, 8, 1, 0, 0, 0])
%!assert <*42241> (datevec ("2013-08-15", "yyyy-mm"), [2013, 8, 1, 0, 0, 0])
%!assert <*42241> (datevec ("2013-08ABC", "yyyy-mm"), [2013, 8, 1, 0, 0, 0])

## yyyy-mm-ddTHH:MM:SSZ
%!assert <*42241> (datevec ("2013-08-15T09:00:35Z"), [2013, 8, 15, 9, 0, 35])
%!assert <*42241> (datevec ("2013-08-15T09:00:35Z", "yyyy-mm-ddTHH:MM:SSZ"), [2013, 8, 15, 9, 0, 35])
%!assert <*42241> (datevec ("2013-08-15T09:00:35ZABC", "yyyy-mm-ddTHH:MM:SSZ"), [2013, 8, 15, 9, 0, 35])

## yyyy-mm-ddTHH:MM:SS.FFFZ
%!assert <*42241> (datevec ("2013-08-15T09:00:35.123Z"), [2013, 8, 15, 9, 0, 35.123])
%!assert <*42241> (datevec ("2013-08-15T09:00:35.123Z", "yyyy-mm-ddTHH:MM:SS.FFFZ"), [2013, 8, 15, 9, 0, 35.123])
%!assert <*42241> (datevec ("2013-08-15T09:00:35.123ZABC", "yyyy-mm-ddTHH:MM:SS.FFFZ"), [2013, 8, 15, 9, 0, 35.123])


## Test input validation
%!error <Invalid call> datevec ()
%!error <none of the standard formats match> datevec ("foobar")
%!error <DATE not parsed correctly with given format> datevec ("foobar", "%d")
%!error <multiple year specifiers> datevec ("1/2/30", "mm/yy/yy")
%!error <multiple month specifiers> datevec ("1/2/30", "mm/mm/yy")
%!error <multiple day specifiers> datevec ("1/2/30", "mm/dd/dd")
%!error <multiple hour specifiers> datevec ("15:38:21.251", "HH:HH:SS")
%!error <multiple minute specifiers> datevec ("15:38:21.251", "MM:MM:SS")
%!error <multiple second specifiers> datevec ("15:38:21.251", "HH:SS:SS")
%!fail ("datevec ('2015-03-31 0:00','YYYY-mm-DD HH:MM')", ...
%!      "warning", "Format specifiers for dates should be lower case");
%!fail ("datevec ('2015-03-31 hh:00','yyyy-mm-dd hh:MM')", ...
%!      "warning", "format specifiers for time should be upper case");

