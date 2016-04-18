"All Latin Verse" Tesserae Experiments 
======================================

What you have here is, for the present, a collection of scripts that perform
Tesserae searches on every possible pair of texts in the Latin verse corpus,
and parse and organize the results. The idea is that two different workgroups
can use the same data: Neil Bernstein's study of intertextual density; and Alex
Nikolaev's study of the network of allusion among Latin authors.

In the future, I hope that both teams will be able to perform the searches they
need using the built-in batch processing functionality of Tesserae, but it
seems that it won't be really stable or full-featured enough in the near
future, so this is essentially a temporary stop-gap. At the same time, it
should be stable enough to rely on for ongoing research until a long-term
solution can be developed.

Quick Start
-----------

For this to work, you must have [VirtualBox](https://www.virtualbox.org) and
[Vagrant](https://www.vagrantup.com) installed, and, at least initially, a
connection to the Internet. Then, at the command line, from within the present
directory, do ```vagrant up```. The virtual machine image will be downloaded
from the Internet and booted (takes a while); then Tesserae itself will be
downloaded from the Internet and installed on the VM (takes even longer).
Finally, the default search set of all Latin verse texts will be run, and the
results saved to a new directory, __output__. When everything is done, use
```vagrant destroy``` to stop the VM and get rid of its invisible, but
substantial, contents (the new __output__ folder won't be affected).

Contents
--------

This workset is arranged as follows. Here you have a Vagrant configuration file
(__Vagrantfile__) that defines a standard Vagrant virtual machine, along with a
couple of bootstrap scripts (__setup/bootstrap.sh__,
__setup/setup.tesserae.sh__) that install Tesserae on the VM, cloning the
official [Tesserae repo](https://github.com/tesserae/tesserae). There's also
some extra metadata here
(__metadata/authors.xml__, __metadata/texts.xml__), including approximate publication
dates for the Latin verse texts. 
One day this information will be standard in Tesserae, but not yet. If you want
to perform searches on your own texts, you will have to add at least minimal
entries to these files on the model of what's there already.
Finally, there are some perl scripts to build
and carry out a list of searches using the Tesserae installation on the VM,
parse the results, and store them in a directory shared by the VM with its host:

 * __scripts/nodelist.pl__

 This script parses the XML metadata files and produces a plain table
(__output/index_text.txt__) of relevant texts with useful statistics such as
token, stem, line, and phrase counts that could be useful in calculating
intertextual density.

 * __scripts/all_la_verse.pl__

 This is the principal script of this workset, generating and then carrying out
a list of Tesserae searches. It saves the list at __output/index_run.txt__
for future reference. Nota bene: the binary Tesserae results are saved to the
home directory of the virtual machine (__/home/vagrant/working__), so they're
not accessible from the host and will be erased by a subsequent ```vagrant
destroy```. (See script documentation to change this behaviour.)

 * __scripts/extract_scores.pl__

 This script parses the results of the searches performed by
__all_la_verse.pl__. The results are saved to __output/scores__. 
By default the results for each search are saved as a separate text
file, consisting of just the scores for each result, to one decimal place,
separated by newlines. The results for each search are named only by a serial
number, use __output/index_run.txt__ to locate a specific search.

For available options and (slightly) more complete documentation, use
```perldoc``` or ```--help``` with any of the above scripts, e.g. ```perldoc
scripts/all_la_verse.pl``` or (from inside the VM)
```/vagrant/scripts/all_la_verse.pl --help```.

How to Work with Vagrant
------------------------

You can log in to the VM by issuing the command ```vagrant ssh``` at your
command line from within the present directory. The present directory will be
accessible as __/vagrant/__. It's probably most intuitive to change to that
directory and work there, e.g., ```
	cd /vagrant
	scripts/all_la_verse.pl
```
You can create new files and/or modify these ones either directly on the host
or from the command-line in the VM. Just remember that the scripts will
probably only work properly when they're running on the VM: it's easy to get
confused and accidentally run them on your own computer, where Tesserae is
probably not installed, at least not where these scripts expect it to be.

The way I usually work is to have the scripts open in my editor on my own
computer, and an ssh session open at the same time to work on the VM. But you
could, for example, use __vi__ to edit the scripts on the VM itself, and just
do all your work inside a Terminal.

You can read more about how Vagrant works at its website (http://vagrantup.com).

Known Issues
------------

__Speed and resources__

Some of the searches performed as part of this experiment are very demanding,
in particular of RAM. A search of the entirety of Silius Italicus' _Punica_
against Ovid's _Metamorphoses_, for example, uses more than 4 GB of memory.
The __Vagrantfile__ allots 6 GB of RAM to the virtual machine. If you don't have
this, I'm not sure what will happen. You can set the value lower, but some
individual searches may fail. If this happens, less-intensive searches won't be
affected, but you'll find the failed searches lacking from the __output/scores__
folder.

By default, the experiment allots two cores to the VM, and runs searches in
parallel to save time. There is the chance that, even if each search
individually fits in memory, two large ones will collide during processing.
In this case, one or both will fail, and the rest will go on as expected. There
are mechanisms for catching this and redoing the lost searches -- by default, 
one repeat will be attempted if failures are detected. During a redo run, the
searches are run serially rather than in parallel, and the __-quiet__ flag is
turned off, so you'll see diagnostic information from individual Tesserae 
searches.

One day, Tesserae will be much less greedy for memory, but not today, I'm
afraid.

Ancillary Scripts
-----------------

 * __scripts/process_tess_an.R__

 A script I'm working on to transform the contents of the __results/__
directory into edges suitable for import into [Gephi](http://gephi.github.io).
Nota bene: R isn't installed by default on the VM, as I generally work with
this script on my own computer. If you want to run it from the VM, do ```sudo
apt-get install r-base``` or append *r-base* to the list of apt packages in
__setup/bootstrap.sh__.

Contact / Collaboration
-----------------------

I'm excited to work together with all our partners on this. I'm really hopeful
that we can find substantial common ground between Neil B's and Alex's groups,
so that each benefits from the other's work and the core Tesserae code benefits
from both. Email me at [cforstall@gmail.com](mailto:cforstall@gmail.com).
