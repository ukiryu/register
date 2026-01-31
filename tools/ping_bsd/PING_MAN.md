                         [1]OpenBSD manual page server

   Manual Page Search Parameters

   Search query: ping____________________________________ (0) man (1)
   apropos
   [8 - System Manager's Manual__] [All Architectures] [OpenBSD-current]
     __________________________________________________________________

   PING(8) System Manager's Manual PING(8)

[2]NAME

   ping, ping6 -- send ICMP ECHO_REQUEST packets to network hosts

[3]SYNOPSIS

   ping [-DdEefgHLnqRv] [-c count] [-I sourceaddr] [-i interval] [-l
   preload] [-p pattern] [-s packetsize] [-T toskeyword] [-t ttl] [-V
   rtable] [-w maxwait] host

   ping6 [-DdEefgHLmnqv] [-c count] [-h hoplimit] [-I sourceaddr] [-i
   interval] [-l preload] [-p pattern] [-s packetsize] [-T toskeyword] [-V
   rtable] [-w maxwait] host

[4]DESCRIPTION

   ping uses the ICMP protocol's mandatory ECHO_REQUEST datagram to elicit
   an ICMP ECHO_REPLY from a host or gateway. These datagrams (pings) have
   an IP and ICMP header, followed by a "struct timeval" and then an
   arbitrary number of pad bytes used to fill out the packet.

   The options are as follows:

   [5]-c count
          Stop sending after count ECHO_REQUEST packets have been sent. If
          count is 0, send an unlimited number of packets.

   [6]-D
          Don't fragment IP packets.

   [7]-d
          Set the SO_DEBUG option on the socket being used. This option
          has no effect on OpenBSD.

   [8]-E
          Emit an audible beep (by sending an ASCII BEL character to the
          standard error output) when no packet is received before the
          next packet is transmitted. To cater for round-trip times that
          are longer than the interval between transmissions, further
          missing packets cause a bell only if the maximum number of
          unreceived packets has increased. This option is disabled for
          flood pings.

   [9]-e
          Emit an audible beep (by sending an ASCII BEL character to the
          standard error output) after each non-duplicate response is
          received. This option is disabled for flood pings.

   [10]-f
          Flood ping. Outputs packets as fast as they come back or one
          hundred times per second, whichever is more. For every
          ECHO_REQUEST sent, a period `.' is printed, while for every
          ECHO_REPLY received a backspace is printed. This provides a
          rapid display of how many packets are being dropped. Only the
          superuser may use this option.

          This can be very hard on a network and should be used with
          caution.

   [11]-g
          Provides a visual display of packets received and lost. For
          every ECHO_REPLY received, an exclamation mark `!' is printed,
          while for every missed packet a period `.' is printed. Duplicate
          and truncated replies are indicated with `D' and `T'
          respectively.

   [12]-H
          Try reverse lookups for addresses.

   [13]-h hoplimit
          (IPv6 only) Set the hoplimit.

   [14]-I sourceaddr
          Set the source address to transmit from, which is useful on
          machines with multiple interfaces. For unicast and multicast
          pings.

   [15]-i interval
          Send one packet every interval seconds. The default is one
          second. The interval may contain a fractional portion. Only the
          superuser may specify a value less than one second. This option
          is incompatible with the -f option.

   [16]-L
          Disable the loopback, so the transmitting host doesn't see the
          ICMP requests. For multicast pings.

   [17]-l preload
          Send preload packets as fast as possible before reverting to
          normal behavior. Only root may set a preload value.

   [18]-m
          (IPv6 only) Do not fragment unicast packets to fit the minimum
          IPv6 MTU. If specified twice, do this for multicast packets as
          well.

   [19]-n
          Numeric output only. No attempt will be made to look up symbolic
          names from addresses in the reply.

   [20]-p pattern
          Specify up to 16 pad bytes to fill out the packet sent. This is
          useful for diagnosing data-dependent problems in a network. For
          example, "-p ff" causes the sent packet to be filled with all
          ones.

   [21]-q
          Quiet output. Nothing is displayed except the summary lines at
          startup time and when finished.

   [22]-R
          (IPv4 only) Record route. Includes the RECORD_ROUTE option in
          the ECHO_REQUEST packet and displays the route buffer on
          returned packets. Note that the IP header is only large enough
          for nine such routes. If more routes come back than should, such
          as due to an illegal spoofed packet, ping will print the route
          list and then truncate it at the correct spot. Many hosts ignore
          or discard this option.

   [23]-s packetsize
          Specify the number of data bytes to be sent. The default is 56,
          which translates into 64 ICMP data bytes when combined with the
          8 bytes of ICMP header data. The maximum packet size is 65467
          for IPv4 and 65527 for IPv6.

   [24]-T toskeyword
          Change the IPv4 TOS or IPv6 Traffic Class value. toskeyword may
          be one of critical, inetcontrol, lowdelay, netcontrol,
          throughput, reliability, or one of the DiffServ Code Points: ef,
          af11 ... af43, cs0 ... cs7; or a number in either hex or
          decimal.

   [25]-t ttl
          (IPv4 only) Use the specified time-to-live.

   [26]-V rtable
          Set the routing table to be used for outgoing packets.

   [27]-v
          Verbose output. ICMP packets other than ECHO_REPLY that are
          received are listed.

   [28]-w maxwait
          Specify the maximum number of seconds to wait for responses
          after the last request has been sent. The default is 10.

   When using ping for fault isolation, it should first be run on the
   local host to verify that the local network interface is up and
   running. Then, hosts and gateways further and further away should be
   "pinged".

   Round trip times and packet loss statistics are computed. If duplicate
   packets are received, they are not included in the packet loss
   calculation, although the round trip time of these packets is used in
   calculating the minimum/average/maximum round trip time numbers and the
   standard deviation.

   When the specified number of packets have been sent (and received), or
   if the program is terminated with a SIGINT, a brief summary is
   displayed. The summary information can also be displayed while ping is
   running by sending it a SIGINFO signal (see the status argument of
   [29]stty(1) for more information).

   This program is intended for use in network testing, measurement and
   management. Because of the load it can impose on the network, it is
   unwise to use ping during normal operations or from automated scripts.

[30]ICMP PACKET DETAILS

   An IP header without options is 20 bytes. An ICMP ECHO_REQUEST packet
   contains an additional 8 bytes worth of ICMP header followed by an
   arbitrary amount of data. When a packetsize is given, this indicates
   the size of this extra piece of data (the default is 56). Thus the
   amount of data received inside of an IP packet of type ICMP ECHO_REPLY
   will always be 8 bytes more than the requested data space (the ICMP
   header).

   If the data space is at least 24 bytes, ping uses the first sixteen
   bytes of this space to include a timestamp which it uses in the
   computation of round trip times. The following 8 bytes store a message
   authentication code. If less than 24 bytes of pad are specified, no
   round trip times are given.

[31]DUPLICATE AND DAMAGED PACKETS

   ping will report duplicate and damaged packets. Duplicate packets
   should never occur, and seem to be caused by inappropriate link-level
   retransmissions. Duplicates may occur in many situations and are rarely
   (if ever) a good sign, although the presence of low levels of
   duplicates may not always be cause for alarm.

   Damaged packets are obviously serious cause for alarm and often
   indicate broken hardware somewhere in the ping packet's path (in the
   network or in the hosts).

[32]TRYING DIFFERENT DATA PATTERNS

   The (inter)network layer should never treat packets differently
   depending on the data contained in the data portion. Unfortunately,
   data-dependent problems have been known to sneak into networks and
   remain undetected for long periods of time. In many cases the
   particular pattern that will have problems is something that doesn't
   have sufficient "transitions", such as all ones or all zeros, or a
   pattern right at the edge, such as almost all zeros. It isn't
   necessarily enough to specify a data pattern of all zeros (for example)
   on the command line because the pattern that is of interest is at the
   data link level, and the relationship between what you type and what
   the controllers transmit can be complicated.

   This means that if you have a data-dependent problem you will probably
   have to do a lot of testing to find it. If you are lucky, you may
   manage to find a file that either can't be sent across your network or
   that takes much longer to transfer than other similar length files. You
   can then examine this file for repeated patterns that you can test
   using the -p option of ping.

[33]TTL DETAILS

   The TTL value of an IP packet represents the maximum number of IP
   routers that the packet can go through before being thrown away. In
   current practice you can expect each router in the Internet to
   decrement the TTL field by exactly one.

   The TCP/IP specification states that the TTL field for TCP packets
   should be set to 60, but many systems use smaller values (4.3BSD uses
   30, 4.2BSD used 15).

   The maximum possible value of this field is 255, and most UNIX systems
   set the TTL field of ICMP ECHO_REQUEST packets to 255. This is why you
   will find you can "ping" some hosts, but not reach them with
   [34]telnet(1) or [35]ftp(1).

   In normal operation, ping prints the TTL value from the packet it
   receives. When a remote system receives a ping packet, it can do one of
   three things with the TTL field in its response:
     * Not change it; this is what Berkeley UNIX systems did before the
       4.3BSD-Tahoe release. In this case the TTL value in the received
       packet will be 255 minus the number of routers in the round trip
       path.
     * Set it to 255; this is what current Berkeley UNIX systems do. In
       this case the TTL value in the received packet will be 255 minus
       the number of routers in the path from the remote system to the
       pinging host.
     * Set it to some other value. Some machines use the same value for
       ICMP packets that they use for TCP packets, for example either 30
       or 60. Others may use completely wild values.

[36]EXIT STATUS

   ping exits 0 if at least one reply is received, and >0 if no reply is
   received or an error occurred.

[37]SEE ALSO

   [38]ifconfig(8), [39]route(8)

[40]HISTORY

   The ping command appeared in 4.3BSD. The ping6 command was originally a
   separate program and first appeared in the WIDE Hydrangea IPv6 protocol
   stack kit.

[41]BUGS

   Many hosts and gateways ignore the RECORD_ROUTE option.

   The maximum IP header length is too small for options like RECORD_ROUTE
   to be completely useful. There's not much that can be done about this,
   however.

   Flood pinging is not recommended in general, and flood pinging the
   broadcast address should only be done under very controlled conditions.

   December 23, 2022 OpenBSD-current

References

   1. https://www.openbsd.org/
   2. file:///var/folders/2t/xmdrn2sd2lv2w49dv0zw9_q00000gp/T/L73855-4272TMP.html#NAME
   3. file:///var/folders/2t/xmdrn2sd2lv2w49dv0zw9_q00000gp/T/L73855-4272TMP.html#SYNOPSIS
   4. file:///var/folders/2t/xmdrn2sd2lv2w49dv0zw9_q00000gp/T/L73855-4272TMP.html#DESCRIPTION
   5. file:///var/folders/2t/xmdrn2sd2lv2w49dv0zw9_q00000gp/T/L73855-4272TMP.html#c
   6. file:///var/folders/2t/xmdrn2sd2lv2w49dv0zw9_q00000gp/T/L73855-4272TMP.html#D
   7. file:///var/folders/2t/xmdrn2sd2lv2w49dv0zw9_q00000gp/T/L73855-4272TMP.html#d
   8. file:///var/folders/2t/xmdrn2sd2lv2w49dv0zw9_q00000gp/T/L73855-4272TMP.html#E
   9. file:///var/folders/2t/xmdrn2sd2lv2w49dv0zw9_q00000gp/T/L73855-4272TMP.html#e
  10. file:///var/folders/2t/xmdrn2sd2lv2w49dv0zw9_q00000gp/T/L73855-4272TMP.html#f
  11. file:///var/folders/2t/xmdrn2sd2lv2w49dv0zw9_q00000gp/T/L73855-4272TMP.html#g
  12. file:///var/folders/2t/xmdrn2sd2lv2w49dv0zw9_q00000gp/T/L73855-4272TMP.html#H
  13. file:///var/folders/2t/xmdrn2sd2lv2w49dv0zw9_q00000gp/T/L73855-4272TMP.html#h
  14. file:///var/folders/2t/xmdrn2sd2lv2w49dv0zw9_q00000gp/T/L73855-4272TMP.html#I
  15. file:///var/folders/2t/xmdrn2sd2lv2w49dv0zw9_q00000gp/T/L73855-4272TMP.html#i
  16. file:///var/folders/2t/xmdrn2sd2lv2w49dv0zw9_q00000gp/T/L73855-4272TMP.html#L
  17. file:///var/folders/2t/xmdrn2sd2lv2w49dv0zw9_q00000gp/T/L73855-4272TMP.html#l
  18. file:///var/folders/2t/xmdrn2sd2lv2w49dv0zw9_q00000gp/T/L73855-4272TMP.html#m
  19. file:///var/folders/2t/xmdrn2sd2lv2w49dv0zw9_q00000gp/T/L73855-4272TMP.html#n
  20. file:///var/folders/2t/xmdrn2sd2lv2w49dv0zw9_q00000gp/T/L73855-4272TMP.html#p
  21. file:///var/folders/2t/xmdrn2sd2lv2w49dv0zw9_q00000gp/T/L73855-4272TMP.html#q
  22. file:///var/folders/2t/xmdrn2sd2lv2w49dv0zw9_q00000gp/T/L73855-4272TMP.html#R
  23. file:///var/folders/2t/xmdrn2sd2lv2w49dv0zw9_q00000gp/T/L73855-4272TMP.html#s
  24. file:///var/folders/2t/xmdrn2sd2lv2w49dv0zw9_q00000gp/T/L73855-4272TMP.html#T
  25. file:///var/folders/2t/xmdrn2sd2lv2w49dv0zw9_q00000gp/T/L73855-4272TMP.html#t
  26. file:///var/folders/2t/xmdrn2sd2lv2w49dv0zw9_q00000gp/T/L73855-4272TMP.html#V
  27. file:///var/folders/2t/xmdrn2sd2lv2w49dv0zw9_q00000gp/T/L73855-4272TMP.html#v
  28. file:///var/folders/2t/xmdrn2sd2lv2w49dv0zw9_q00000gp/T/L73855-4272TMP.html#w
  29. file:///stty.1
  30. file:///var/folders/2t/xmdrn2sd2lv2w49dv0zw9_q00000gp/T/L73855-4272TMP.html#ICMP_PACKET_DETAILS
  31. file:///var/folders/2t/xmdrn2sd2lv2w49dv0zw9_q00000gp/T/L73855-4272TMP.html#DUPLICATE_AND_DAMAGED_PACKETS
  32. file:///var/folders/2t/xmdrn2sd2lv2w49dv0zw9_q00000gp/T/L73855-4272TMP.html#TRYING_DIFFERENT_DATA_PATTERNS
  33. file:///var/folders/2t/xmdrn2sd2lv2w49dv0zw9_q00000gp/T/L73855-4272TMP.html#TTL_DETAILS
  34. file:///telnet.1
  35. file:///ftp.1
  36. file:///var/folders/2t/xmdrn2sd2lv2w49dv0zw9_q00000gp/T/L73855-4272TMP.html#EXIT_STATUS
  37. file:///var/folders/2t/xmdrn2sd2lv2w49dv0zw9_q00000gp/T/L73855-4272TMP.html#SEE_ALSO
  38. file:///ifconfig.8
  39. file:///route.8
  40. file:///var/folders/2t/xmdrn2sd2lv2w49dv0zw9_q00000gp/T/L73855-4272TMP.html#HISTORY
  41. file:///var/folders/2t/xmdrn2sd2lv2w49dv0zw9_q00000gp/T/L73855-4272TMP.html#BUGS
