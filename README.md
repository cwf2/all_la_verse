"All Latin Verse" Tesserae Experiments
======================================

What you have here is, for the present, a collection of scripts that perform Tesserae searches on every possible pair of texts in the Latin verse corpus, and parse and organize the results. The idea is that two different workgroups can use the same data: Neil Bernstein's study of intertextual density; and Alex Nikolaev's study of the network of allusion among Latin authors. In the future, I hope that both teams will be able to perform the searches they need using the built-in batch processing functionality of Tesserae, but it seems that it won't be really stable or full-featured enough in the near future, so this is essentially a stop-gap hack.

Quick Start
-----------

For this to work, you must have [VirtualBox](https://www.virtualbox.org) and [Vagrant](https://www.vagrantup.com) installed, and, at least initially, a connection to the Internet. Then, at the command line, from within the present directory, do ```vagrant up```. The virtual machine image will be downloaded from the Internet and booted (takes a while); then Tesserae itself will be downloaded from the Internet and installed on the VM (takes even longer). Finally, the default search set of all Latin verse texts will be run, and the results saved to a new directory, __results__. When everything is done, use ```vagrant destroy``` to stop the VM and get rid of its invisible, but substantial, contents (the new __results__ folder won't be affected).

Contents
--------

This workset is arranged as follows. Here you have a Vagrant file that defines a standard Vagrant virtual machine, along with a couple of bootstrap scripts (__setup/bootstrap.sh__, __setup/setup.tesserae.sh__) that install Tesserae on the VM, cloning my repo rather than the official one. There's also some extra metadata here (__metadata/authors.xml__, __metadata/texts.xml__), extracted from the *metadata.db* branch of my Tesserae repo, including approximate publication dates for the Latin verse texts. Finally, there are some perl scripts to build and carry out a list of searches using the Tesserae installation on the VM, parse the results, and store them in a directory shared by the VM with its host:

 * __scripts/nodelist.pl__

   This script parses the XML metadata files and produces a plain table (_metadata/index_text.txt_) of relevant texts with useful statistics such as token, stem, line, and phrase counts that could be useful in calculating intertextual density.
   
 * __scripts/all_la_verse.pl__
 
   This is the principal script of this workset, generating and then carrying out a list of Tesserae searches. It saves the list at __metadata/index_run.txt__ for future reference. Nota bene: the binary Tesserae results are saved to the home directory of the virtual machine (__/home/vagrant/working__), so they're not accessible from the host and will be erased by a subsequent ```vagrant destroy```.
   
 * __scripts/extract_scores.pl___
 
   This script parses the results of the searches performed by __all_la_verse.pl__. The results are saved to __/vagrant/results__ on the VM, which means they should be shared with the host (i.e. in the current directory). By default the results for each search are saved as a separate text file, consisting of just the scores for each result, to one decimal place, separated by newlines. The results for each search are named only by a serial number, use __metadata/index_run.txt__ to locate a specific search.
   
For available options and (slightly) more complete documentation, use ```perldoc``` or ```--help``` with any of the above scripts, e.g. ```perldoc scripts/all_la_verse.pl``` or (from inside the VM) ```/vagrant/scripts/all_la_verse.pl --help```.

How to Work with Vagrant
------------------------

If you're new to Vagrant, the basic idea is that the Tesserae installation that's being used here is installed on a virtual machine managed behind the scenes by VirtualBox. This means that you don't have to worry about the particulars of installing it on your own machine (Mac, Windows, whatever). It also means that the scripts here aren't meant to be run on your computer, but on the VM. The present directory is shared between your computer and the VM (where it appears as __/vagrant/__), so if you want to edit the scripts using your favourite editor, go ahead, and the changes will be reflected in real time on the virtual machine. Likewise, anything you create in this directory will appear on the VM, and anything the VM creates (like the __results__ folder) will be visible on your machine.

You can log in to the VM by issuing the command ```vagrant ssh``` at your command line from within the present directory. Then you can run these scripts yourself or create your own to work with the virtual Tesserae or the search results; you'll just have to do it from the command line interface. Just remember that the scripts will probably only work properly when they're running on the VM: it's easy to get confused and accidentally run them on your own computer, where Tesserae is probably not installed, or not where these scripts expect it to be.

The way I usually work is to have the scripts open in my editor on my own computer, and an ssh session open at the same time to work on the VM. But you could, for example, use __vi__ to edit the scripts on the VM itself, and just do all your work inside a Terminal.

You can read more about how Vagrant works at its website (http://vagrantup.com).

Ancillary Scripts
-----------------

 * __scripts/process_tess_an.R__
 
 A script I'm working on to transform the contents of the __results/__ directory into edges suitable for import into [Gephi](http://gephi.github.io). Nota bene: R isn't installed by default on the VM, as I generally work with this script on my own computer. If you want to run it from the VM, do ```sudo apt-get install r-base``` or append *r-base* to the list of apt packages in __setup/bootstrap.sh__.
 
 * __scripts/metadata_export_text.pl__
 
 This script is used to pull XML metadata from individual Tesserae texts and concatenate it in the file __texts.xml__. It isn't meant to be run on the VM; it only works with the *metadata_db* branch of my Tesserae code, where Tess files are stored in XML format. I only saved it here because it pertained to this code and probably won't be needed in the actual *metadata_db* branch. By default you don't need it anyway, since __texts.xml__ has already been created. But if the corpus is updated before a new release of Tesserae makes this entire workset redundant, I can use this script again to get the updated metadata.

Contact / Collaboration
-----------------------

I'm excited to work together with all our partners on this. I'm really hopeful that we can find substantial common ground between Neil B's and Alex's groups, so that each benefits from the other's work and the core Tesserae code benefits from both. Email me at [cforstall@gmail.com](mailto:cforstall@gmail.com).



