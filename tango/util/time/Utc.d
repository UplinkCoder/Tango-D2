/*******************************************************************************

        copyright:      Copyright (c) 2007 Kris Bell. All rights reserved

        license:        BSD style: $(LICENSE)

        version:        Feb 2007: Initial release

        author:         Kris

*******************************************************************************/

module tango.util.time.Utc;

private import  tango.sys.Common;

private import  tango.core.Exception;

public  import  tango.core.Type : Interval, Time;

/******************************************************************************

        Exposes UTC time relative to Jan 1st, 1 AD. These values are
        based upon a clock-tick of 100ns, giving them a span of greater
        than 10,000 years. Units of Time are the foundation of most time
        and date functionality in Tango.

        Interval is another type of time period, used for measuring a
        much shorter duration; typically used for timeout periods and
        for high-resolution timers. These intervals are measured in
        units of 1 second, and support fractional units (0.001 = 1ms).

*******************************************************************************/

struct Utc
{
        /***********************************************************************

                Basic functions for epoch time

        ***********************************************************************/

        version (Win32)
        {
                /***************************************************************

                        Return the current time as UTC since the epoch

                ***************************************************************/

                static Time now ()
                {
                        FILETIME fTime = void;
                        GetSystemTimeAsFileTime (&fTime);
                        return convert (fTime);
                }

                /***************************************************************

                        Return the current local time

                ***************************************************************/

                static Time local ()
                {
                        return cast(Time) (now + bias);
                }

                /***************************************************************

                        Return the timezone relative to GMT. The value is 
                        negative when west of GMT

                ***************************************************************/

                static Time zone ()
                {
                        TIME_ZONE_INFORMATION tz = void;

                        auto tmp = GetTimeZoneInformation (&tz);
                        return cast(Time) (-Time.TicksPerMinute * tz.Bias);
                }

                /***************************************************************

                        Convert FILETIME to a Time

                ***************************************************************/

                static Time convert (FILETIME time)
                {
                        return cast(Time) (Time.TicksTo1601 + *cast(ulong*) &time);
                }

                /***************************************************************

                        Convert Time to a FILETIME

                ***************************************************************/

                static FILETIME convert (Time span)
                {
                        FILETIME time = void;

                        span -= span.TicksTo1601;
                        assert (span >= 0);
                        *cast(long*) &time.dwLowDateTime = span;
                        return time;
                }

                /***************************************************************

                        Return the local bias, adjusted for DST, in seconds. 
                        The value is negative when west of GMT

                ***************************************************************/

                package static long bias ()
                {
                        int bias;
                        TIME_ZONE_INFORMATION tz = void;

                        switch (GetTimeZoneInformation (&tz))
                               {
                               default:
                                    bias = tz.Bias;
                                    break;
                               case 1:
                                    bias = tz.Bias + tz.StandardBias;
                                    break;
                               case 2:
                                    bias = tz.Bias + tz.DaylightBias;
                                    break;
                               }

                        return -Time.TicksPerMinute * bias;
                }
        }

        version (Posix)
        {
                /***************************************************************

                        Return the current time as UTC since the epoch

                ***************************************************************/

                static Time now ()
                {
                        timeval tv = void;
                        if (gettimeofday (&tv, null))
                            throw new PlatformException ("Time.utc :: Posix timer is not available");

                        return convert (tv);
                }

                /***************************************************************

                        Return the current local time

                ***************************************************************/

                static Time local ()
                {
                        tm t = void;
                        timeval tv = void;
                        gettimeofday (&tv, null);
                        localtime_r (&tv.tv_sec, &t);
                        tv.tv_sec = timegm (&t);
                        return convert (tv);
                }

                /***************************************************************

                        Return the timezone relative to GMT. The value is 
                        negative when west of GMT

                ***************************************************************/

                static Time zone ()
                {
                        version (darwin)
                                {
                                timezone_t tz = void;
                                gettimeofday (null, &tz);
                                return cast(Time) (-Time.TicksPerMinute * tz.tz_minuteswest);
                                }
                             else
                                return cast(Time) (-Time.TicksPerSecond * timezone);
                }

                /***************************************************************

                        Convert timeval to a Time

                ***************************************************************/

                static Time convert (inout timeval tv)
                {
                        return cast(Time) (Time.TicksTo1970 + (1_000_000L * tv.tv_sec + tv.tv_usec) * 10);
                }

                /***************************************************************

                        Convert Time to a timeval

                ***************************************************************/

                static timeval convert (Time time)
                {
                        timeval tv = void;

                        time -= time.TicksTo1970;
                        assert (time >= 0);
                        time /= 10L;
                        tv.tv_sec  = cast (typeof(tv.tv_sec))  (time / 1_000_000L);
                        tv.tv_usec = cast (typeof(tv.tv_usec)) (time - 1_000_000L * tv.tv_sec);
                        return tv;
                }
        }
}

version (Posix)
{
    version (darwin) {}
    else
    {
        static this()
        {
            tzset();
        }
    }
}



debug (UnitTest)
{
        unittest 
        {
                auto time = Utc.now;
                assert (Utc.convert(Utc.convert(time)) is time);
        }
}
