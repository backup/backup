---
layout: main
title: Compressor::Custom (Extra)
---

Compressor::Custom (Extra)
==========================

Backup can support any compressor you like. Besides the standard [gzip][] and [bzip2][] compressors, multi-threaded
versions of each are also available, like [pigz][] and [pbzip2][]. There's also [xz][], the successor to LZMA, which
supports multi-threading as of v5.1.1alpha.

To configure a custom compressor, simply use the following:

``` rb
Model.new(:my_backup, 'My Backup') do

  # Archives, Databases, etc...

  compress_with Custom do |compression|
    compression.command = 'pbzip2 -p2'
    compression.extension = '.bz2'
  end
end
```

As long as the compressor accepts input on STDIN and writes to STDOUT, it should work.  
i.e. `tar -cf - my_files/ | %compression.command% > my_files.tar.%compression.extension%`


Also, note that setting defaults for the `Custom` compressor works the same as with `Gzip` and `Bzip2`.

```rb
Compressor::Custom.defaults do |compressor|
  compressor.command = 'xz -1'
  compressor.extension = '.xz'
end
```


Compressor Benchmarks
---------------------

The following tables provide some benchmarks for [gzip][], [bzip2][] and [xz][] using a single CPU core, and using 2 CPU cores.
For multi-threaded **gzip** and **bzip2** statistics, [pigz][] and [pbzip2][] were used. **xz** supports multi-threaded
operation as of v5.1.1alpha.

Keep in mind these are simply provided to give you an idea of the differences between these compressors,
and the different levels of compression they support. Compression/Decompression times will vary depending on your system.
Memory usage should be the same. If you decide to configure a Custom compressor, you should perform some benchmarks
on your own system, and be sure to read the compressor's documentation.

The source for these tests was a 461 MB tar archive of the Linux Kernel v3.2.12 source distribution.  
Entries in **bold** represent the default settings for the compressor.

<div class="compressor-benchmarks">
  <table>
    <tr>
      <th colspan="6"><div align="center">Compression using one CPU core</div></th>
    </tr>
    <tr>
      <th colspan="2">&nbsp;</th>
      <th colspan="2"><div align="center">Compression</div></th>
      <th colspan="2"><div align="center">Decompression</div></th>
    </tr>
    <tr>
      <th><div align="center">Command</div></th>
      <th><div align="center">Compressed Size</div></th>
      <th><div align="center">Time</div></th>
      <th><div align="center">Memory</div></th>
      <th><div align="center">Time</div></th>
      <th><div align="center">Memory</div></th>
    </tr>
    <tr>
      <td><div align="left">gzip -1</div></td>
      <td><div align="right">125,370 KB (72.81%)</div></td>
      <td><div align="center">00:15</div></td>
      <td><div align="right">1,228 KB</div></td>
      <td><div align="center">00:06</div></td>
      <td><div align="right">1,228 KB</div></td>
    </tr>
    <tr>
      <td><div align="left">gzip -2</div></td>
      <td><div align="right">119,653 KB (74.05%)</div></td>
      <td><div align="center">00:17</div></td>
      <td><div align="right">1,224 KB</div></td>
      <td><div align="center">00:06</div></td>
      <td><div align="right">1,228 KB</div></td>
    </tr>
    <tr>
      <td><div align="left">gzip -3</div></td>
      <td><div align="right">115,649 KB (74.91%)</div></td>
      <td><div align="center">00:19</div></td>
      <td><div align="right">1,228 KB</div></td>
      <td><div align="center">00:06</div></td>
      <td><div align="right">1,232 KB</div></td>
    </tr>
    <tr>
      <td><div align="left">gzip -4</div></td>
      <td><div align="right">107,445 KB (76.69%)</div></td>
      <td><div align="center">00:22</div></td>
      <td><div align="right">1,228 KB</div></td>
      <td><div align="center">00:05</div></td>
      <td><div align="right">1,228 KB</div></td>
    </tr>
    <tr>
      <td><div align="left">gzip -5</div></td>
      <td><div align="right">103,257 KB (77.60%)</div></td>
      <td><div align="center">00:29</div></td>
      <td><div align="right">1,228 KB</div></td>
      <td><div align="center">00:05</div></td>
      <td><div align="right">1,232 KB</div></td>
    </tr>
    <tr>
      <td><div align="left"><b>gzip -6</b></div></td>
      <td><div align="right"><b>101,612 KB (77.96%)</b></div></td>
      <td><div align="center"><b>00:39</b></div></td>
      <td><div align="right"><b>1,228 KB</b></div></td>
      <td><div align="center"><b>00:05</b></div></td>
      <td><div align="right"><b>1,228 KB</b></div></td>
    </tr>
    <tr>
      <td><div align="left">gzip -7</div></td>
      <td><div align="right">101,161 KB (78.06%)</div></td>
      <td><div align="center">00:46</div></td>
      <td><div align="right">1,228 KB</div></td>
      <td><div align="center">00:05</div></td>
      <td><div align="right">1,228 KB</div></td>
    </tr>
    <tr>
      <td><div align="left">gzip -8</div></td>
      <td><div align="right">100,859 KB (78.12%)</div></td>
      <td><div align="center">00:59</div></td>
      <td><div align="right">1,224 KB</div></td>
      <td><div align="center">00:05</div></td>
      <td><div align="right">1,228 KB</div></td>
    </tr>
    <tr>
      <td><div align="left">gzip -9</div></td>
      <td><div align="right">100,785 KB (78.14%)</div></td>
      <td><div align="center">01:06</div></td>
      <td><div align="right">1,232 KB</div></td>
      <td><div align="center">00:05</div></td>
      <td><div align="right">1,228 KB</div></td>
    </tr>
    <tr>
      <th colspan="6">&nbsp;</th>
    </tr>
    <tr>
      <td><div align="left">bzip2 -1</div></td>
      <td><div align="right">94,924 KB (79.41%)</div></td>
      <td><div align="center">01:42</div></td>
      <td><div align="right">1,592 KB</div></td>
      <td><div align="center">00:27</div></td>
      <td><div align="right">1,228 KB</div></td>
    </tr>
    <tr>
      <td><div align="left">bzip2 -2</div></td>
      <td><div align="right">88,615 KB (80.78%)</div></td>
      <td><div align="center">01:42</div></td>
      <td><div align="right">2,384 KB</div></td>
      <td><div align="center">00:27</div></td>
      <td><div align="right">1,324 KB</div></td>
    </tr>
    <tr>
      <td><div align="left">bzip2 -3</div></td>
      <td><div align="right">85,605 KB (81.43%)</div></td>
      <td><div align="center">01:44</div></td>
      <td><div align="right">2,912 KB</div></td>
      <td><div align="center">00:28</div></td>
      <td><div align="right">1,588 KB</div></td>
    </tr>
    <tr>
      <td><div align="left">bzip2 -4</div></td>
      <td><div align="right">83,748 KB (81.83%)</div></td>
      <td><div align="center">01:48</div></td>
      <td><div align="right">3,704 KB</div></td>
      <td><div align="center">00:28</div></td>
      <td><div align="right">2,116 KB</div></td>
    </tr>
    <tr>
      <td><div align="left">bzip2 -5</div></td>
      <td><div align="right">82,480 KB (82.11%)</div></td>
      <td><div align="center">01:50</div></td>
      <td><div align="right">4,496 KB</div></td>
      <td><div align="center">00:29</div></td>
      <td><div align="right">2,384 KB</div></td>
    </tr>
    <tr>
      <td><div align="left">bzip2 -6</div></td>
      <td><div align="right">81,385 KB (82.35%)</div></td>
      <td><div align="center">01:52</div></td>
      <td><div align="right">5,288 KB</div></td>
      <td><div align="center">00:30</div></td>
      <td><div align="right">2,908 KB</div></td>
    </tr>
    <tr>
      <td><div align="left">bzip2 -7</div></td>
      <td><div align="right">80,629 KB (82.51%)</div></td>
      <td><div align="center">01:55</div></td>
      <td><div align="right">6,076 KB</div></td>
      <td><div align="center">00:31</div></td>
      <td><div align="right">3,172 KB</div></td>
    </tr>
    <tr>
      <td><div align="left">bzip2 -8</div></td>
      <td><div align="right">79,986 KB (82.65%)</div></td>
      <td><div align="center">01:58</div></td>
      <td><div align="right">6,868 KB</div></td>
      <td><div align="center">00:32</div></td>
      <td><div align="right">3,704 KB</div></td>
    </tr>
    <tr>
      <td><div align="left"><b>bzip2 -9</b></div></td>
      <td><div align="right"><b>79,466 KB (82.76%)</b></div></td>
      <td><div align="center"><b>02:01</b></div></td>
      <td><div align="right"><b>7,660 KB</b></div></td>
      <td><div align="center"><b>00:33</b></div></td>
      <td><div align="right"><b>3,964 KB</b></div></td>
    </tr>
    <tr>
      <th colspan="6">&nbsp;</th>
    </tr>
    <tr>
      <td><div align="left">xz -1</div></td>
      <td><div align="right">85,996 KB (81.35%)</div></td>
      <td><div align="center">01:17</div></td>
      <td><div align="right">9,536 KB</div></td>
      <td><div align="center">00:17</div></td>
      <td><div align="right">1,960 KB</div></td>
    </tr>
    <tr>
      <td><div align="left">xz -2</div></td>
      <td><div align="right">81,778 KB (82.26%)</div></td>
      <td><div align="center">01:48</div></td>
      <td><div align="right">17,224 KB</div></td>
      <td><div align="center">00:16</div></td>
      <td><div align="right">2,984 KB</div></td>
    </tr>
    <tr>
      <td><div align="left">xz -3</div></td>
      <td><div align="right">79,704 KB (82.71%)</div></td>
      <td><div align="center">02:43</div></td>
      <td><div align="right">32,580 KB</div></td>
      <td><div align="center">00:15</div></td>
      <td><div align="right">5,028 KB</div></td>
    </tr>
    <tr>
      <td><div align="left">xz -4</div></td>
      <td><div align="right">75,247 KB (83.68%)</div></td>
      <td><div align="center">04:29</div></td>
      <td><div align="right">49,156 KB</div></td>
      <td><div align="center">00:15</div></td>
      <td><div align="right">5,000 KB</div></td>
    </tr>
    <tr>
      <td><div align="left">xz -5</div></td>
      <td><div align="right">69,517 KB (84.92%)</div></td>
      <td><div align="center">06:28</div></td>
      <td><div align="right">96,232 KB</div></td>
      <td><div align="center">00:14</div></td>
      <td><div align="right">9,096 KB</div></td>
    </tr>
    <tr>
      <td><div align="left"><b>xz -6</b></div></td>
      <td><div align="right"><b>68,167 KB (85.21%)</b></div></td>
      <td><div align="center"><b>07:45</b></div></td>
      <td><div align="right"><b>96,228 KB</b></div></td>
      <td><div align="center"><b>00:14</b></div></td>
      <td><div align="right"><b>9,096 KB</b></div></td>
    </tr>
    <tr>
      <td><div align="left">xz -7</div></td>
      <td><div align="right">66,825 KB (85.50%)</div></td>
      <td><div align="center">08:13</div></td>
      <td><div align="right">190,440 KB</div></td>
      <td><div align="center">00:14</div></td>
      <td><div align="right">17,280 KB</div></td>
    </tr>
    <tr>
      <td><div align="left">xz -8</div></td>
      <td><div align="right">66,045 KB (85.67%)</div></td>
      <td><div align="center">08:43</div></td>
      <td><div align="right">378,856 KB</div></td>
      <td><div align="center">00:13</div></td>
      <td><div align="right">33,668 KB</div></td>
    </tr>
    <tr>
      <td><div align="left">xz -9</div></td>
      <td><div align="right">65,419 KB (85.81%)</div></td>
      <td><div align="center">09:09</div></td>
      <td><div align="right">690,144 KB</div></td>
      <td><div align="center">00:13</div></td>
      <td><div align="right">66,432 KB</div></td>
    </tr>
  </table>

  <table>
    <tr>
      <th colspan="6"><div align="center">Compression using two CPU cores</div></th>
    </tr>
    <tr>
      <th colspan="2">&nbsp;</th>
      <th colspan="2"><div align="center">Compression</div></th>
      <th colspan="2"><div align="center">Decompression</div></th>
    </tr>
    <tr>
      <th><div align="center">Command</div></th>
      <th><div align="center">Compressed Size</div></th>
      <th><div align="center">Time</div></th>
      <th><div align="center">Memory</div></th>
      <th><div align="center">Time</div></th>
      <th><div align="center">Memory</div></th>
    </tr>
    <tr>
      <td><div align="left">pigz -p2 -1</div></td>
      <td><div align="right">125,123 KB (72.86%)</div></td>
      <td><div align="center">00:09</div></td>
      <td><div align="right">2,596 KB</div></td>
      <td><div align="center">00:04</div></td>
      <td><div align="right">1,144 KB</div></td>
    </tr>
    <tr>
      <td><div align="left">pigz -p2 -2</div></td>
      <td><div align="right">119,352 KB (74.11%)</div></td>
      <td><div align="center">00:10</div></td>
      <td><div align="right">2,428 KB</div></td>
      <td><div align="center">00:04</div></td>
      <td><div align="right">1,148 KB</div></td>
    </tr>
    <tr>
      <td><div align="left">pigz -p2 -3</div></td>
      <td><div align="right">115,216 KB (75.01%)</div></td>
      <td><div align="center">00:12</div></td>
      <td><div align="right">2,548 KB</div></td>
      <td><div align="center">00:04</div></td>
      <td><div align="right">1,148 KB</div></td>
    </tr>
    <tr>
      <td><div align="left">pigz -p2 -4</div></td>
      <td><div align="right">107,485 KB (76.68%)</div></td>
      <td><div align="center">00:14</div></td>
      <td><div align="right">2,536 KB</div></td>
      <td><div align="center">00:04</div></td>
      <td><div align="right">1,148 KB</div></td>
    </tr>
    <tr>
      <td><div align="left">pigz -p2 -5</div></td>
      <td><div align="right">103,282 KB (77.60%)</div></td>
      <td><div align="center">00:18</div></td>
      <td><div align="right">2,560 KB</div></td>
      <td><div align="center">00:04</div></td>
      <td><div align="right">1,144 KB</div></td>
    </tr>
    <tr>
      <td><div align="left"><b>pigz -p2 -6</b></div></td>
      <td><div align="right"><b>101,631 KB (77.95%)</b></div></td>
      <td><div align="center"><b>00:23</b></div></td>
      <td><div align="right"><b>2,612 KB</b></div></td>
      <td><div align="center"><b>00:04</b></div></td>
      <td><div align="right"><b>1,148 KB</b></div></td>
    </tr>
    <tr>
      <td><div align="left">pigz -p2 -7</div></td>
      <td><div align="right">101,177 KB (78.05%)</div></td>
      <td><div align="center">00:26</div></td>
      <td><div align="right">2,584 KB</div></td>
      <td><div align="center">00:04</div></td>
      <td><div align="right">1,148 KB</div></td>
    </tr>
    <tr>
      <td><div align="left">pigz -p2 -8</div></td>
      <td><div align="right">100,872 KB (78.12%)</div></td>
      <td><div align="center">00:33</div></td>
      <td><div align="right">2,568 KB</div></td>
      <td><div align="center">00:04</div></td>
      <td><div align="right">1,152 KB</div></td>
    </tr>
    <tr>
      <td><div align="left">pigz -p2 -9</div></td>
      <td><div align="right">100,810 KB (78.13%)</div></td>
      <td><div align="center">00:37</div></td>
      <td><div align="right">2,572 KB</div></td>
      <td><div align="center">00:04</div></td>
      <td><div align="right">1,144 KB</div></td>
    </tr>
    <tr>
      <th colspan="6">&nbsp;</th>
    </tr>
    <tr>
      <td><div align="left">pbzip2 -p2 -1</div></td>
      <td><div align="right">95,335 KB (79.32%)</div></td>
      <td><div align="center">00:51</div></td>
      <td><div align="right">8,084 KB</div></td>
      <td><div align="center">00:14</div></td>
      <td><div align="right">7,116 KB</div></td>
    </tr>
    <tr>
      <td><div align="left">pbzip2 -p2 -2</div></td>
      <td><div align="right">89,381 KB (80.61%)</div></td>
      <td><div align="center">00:51</div></td>
      <td><div align="right">10,028 KB</div></td>
      <td><div align="center">00:14</div></td>
      <td><div align="right">7,908 KB</div></td>
    </tr>
    <tr>
      <td><div align="left">pbzip2 -p2 -3</div></td>
      <td><div align="right">86,056 KB (81.33%)</div></td>
      <td><div align="center">00:52</div></td>
      <td><div align="right">11,412 KB</div></td>
      <td><div align="center">00:15</div></td>
      <td><div align="right">8,360 KB</div></td>
    </tr>
    <tr>
      <td><div align="left">pbzip2 -p2 -4</div></td>
      <td><div align="right">84,725 KB (81.62%)</div></td>
      <td><div align="center">00:54</div></td>
      <td><div align="right">12,008 KB</div></td>
      <td><div align="center">00:15</div></td>
      <td><div align="right">9,212 KB</div></td>
    </tr>
    <tr>
      <td><div align="left">pbzip2 -p2 -5</div></td>
      <td><div align="right">83,373 KB (81.91%)</div></td>
      <td><div align="center">00:55</div></td>
      <td><div align="right">14,152 KB</div></td>
      <td><div align="center">00:15</div></td>
      <td><div align="right">9,588 KB</div></td>
    </tr>
    <tr>
      <td><div align="left">pbzip2 -p2 -6</div></td>
      <td><div align="right">83,024 KB (81.99%)</div></td>
      <td><div align="center">00:56</div></td>
      <td><div align="right">15,120 KB</div></td>
      <td><div align="center">00:16</div></td>
      <td><div align="right">10,712 KB</div></td>
    </tr>
    <tr>
      <td><div align="left">pbzip2 -p2 -7</div></td>
      <td><div align="right">82,332 KB (82.14%)</div></td>
      <td><div align="center">00:59</div></td>
      <td><div align="right">17,860 KB</div></td>
      <td><div align="center">00:17</div></td>
      <td><div align="right">11,576 KB</div></td>
    </tr>
    <tr>
      <td><div align="left">pbzip2 -p2 -8</div></td>
      <td><div align="right">81,041 KB (82.42%)</div></td>
      <td><div align="center">01:01</div></td>
      <td><div align="right">17,928 KB</div></td>
      <td><div align="center">00:18</div></td>
      <td><div align="right">11,312 KB</div></td>
    </tr>
    <tr>
      <td><div align="left"><b>pbzip2 -p2 -9</b></div></td>
      <td><div align="right"><b>79,651 KB (82.72%)</b></div></td>
      <td><div align="center"><b>01:02</b></div></td>
      <td><div align="right"><b>19,076 KB</b></div></td>
      <td><div align="center"><b>00:18</b></div></td>
      <td><div align="right"><b>11,808 KB</b></div></td>
    </tr>
    <tr>
      <th colspan="6">&nbsp;</th>
    </tr>
    <tr>
      <td><div align="left">xz -T2 -1</div></td>
      <td><div align="right">86,964 KB (81.14%)</div></td>
      <td><div align="center">00:37</div></td>
      <td><div align="right">38,288 KB</div></td>
      <td><div align="center">00:17</div></td>
      <td><div align="right">1,928 KB</div></td>
    </tr>
    <tr>
      <td><div align="left">xz -T2 -2</div></td>
      <td><div align="right">82,603 KB (82.08%)</div></td>
      <td><div align="center">00:55</div></td>
      <td><div align="right">62,724 KB</div></td>
      <td><div align="center">00:16</div></td>
      <td><div align="right">2,948 KB</div></td>
    </tr>
    <tr>
      <td><div align="left">xz -T2 -3</div></td>
      <td><div align="right">80,236 KB (82.60%)</div></td>
      <td><div align="center">01:26</div></td>
      <td><div align="right">119,480 KB</div></td>
      <td><div align="center">00:16</div></td>
      <td><div align="right">4,996 KB</div></td>
    </tr>
    <tr>
      <td><div align="left">xz -T2 -4</div></td>
      <td><div align="right">75,941 KB (83.53%)</div></td>
      <td><div align="center">02:14</div></td>
      <td><div align="right">148,776 KB</div></td>
      <td><div align="center">00:15</div></td>
      <td><div align="right">4,992 KB</div></td>
    </tr>
    <tr>
      <td><div align="left">xz -T2 -5</div></td>
      <td><div align="right">70,214 KB (84.77%)</div></td>
      <td><div align="center">03:14</div></td>
      <td><div align="right">274,728 KB</div></td>
      <td><div align="center">00:14</div></td>
      <td><div align="right">9,088 KB</div></td>
    </tr>
    <tr>
      <td><div align="left"><b>xz -T2 -6</b></div></td>
      <td><div align="right"><b>68,894 KB (85.06%)</b></div></td>
      <td><div align="center"><b>03:54</b></div></td>
      <td><div align="right"><b>274,748 KB</b></div></td>
      <td><div align="center"><b>00:14</b></div></td>
      <td><div align="right"><b>9,092 KB</b></div></td>
    </tr>
    <tr>
      <td><div align="left">xz -T2 -7</div></td>
      <td><div align="right">67,374 KB (85.39%)</div></td>
      <td><div align="center">04:27</div></td>
      <td><div align="right">526,624 KB</div></td>
      <td><div align="center">00:14</div></td>
      <td><div align="right">17,284 KB</div></td>
    </tr>
    <tr>
      <td><div align="left">xz -T2 -8</div></td>
      <td><div align="right">66,406 KB (85.60%)</div></td>
      <td><div align="center">04:56</div></td>
      <td><div align="right">1,028,992 KB</div></td>
      <td><div align="center">00:13</div></td>
      <td><div align="right">33,668 KB</div></td>
    </tr>
    <tr>
      <td><div align="left">xz -T2 -9</div></td>
      <td><div align="right">65,708 KB (85.75%)</div></td>
      <td><div align="center">05:12</div></td>
      <td><div align="right">1,845,168 KB</div></td>
      <td><div align="center">00:13</div></td>
      <td><div align="right">66,432 KB</div></td>
    </tr>
  </table>
</div>

[gzip]: https://en.wikipedia.org/wiki/Gzip  
[bzip2]: https://en.wikipedia.org/wiki/Bzip2  
[pigz]: http://zlib.net/pigz/  
[pbzip2]: http://compression.ca/pbzip2/  
[xz]: https://en.wikipedia.org/wiki/XZ_Utils  

{% include markdown_links %}
