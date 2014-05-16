#!/usr/bin/perl
# An example script demonstrating the use of BioMart API.
# This perl API representation is only available for configuration versions >=  0.5 
use strict; use warnings FATAL => 'all';
use BioMart::Initializer;
use BioMart::Query;
use BioMart::QueryRunner;
use Getopt::Std;
use vars qw($opt_c $opt_r);
getopts("c:r:");

die "
usage: $0 RUN

Optional:
-c <cached/clean>
-r <registry file>

Explanation:

-c: Cache status. Default: \'cached\'
Use \'clean\' for first time run or if you want to update ensembl
Running \'clean\' will download all file locations therefore it might take >30 minutes. 
During this time there will be \'uninitialized\' perl error message which is a trivial biomart bug and doesn\'t affect anything

-r: Registry file location. Default: /usr/local/bin/Perl/biomart/registry.xml
The xml file can be downloaded from: http://www.biomart.org/biomart/martservice?type=registry
Delete registries that are not needed because it increase cache download time

Requires biomart-perl
http://www.biomart.org/other/install-overview.html
Section 1.2 and 1.4 (specifically 1.4.3)

" unless @ARGV;

my $regFile     = defined($opt_r) ? $opt_r : "/usr/local/bin/Perl/biomart/registry.xml";
my $action      = defined($opt_c) ? $opt_c : 'cached'; 
my ($regFolder) = $regFile =~ /^(.+)\/\w+\.\w+/;
my $regCache    = "$regFolder/cachedRegistries/registry.xml.cached";
sanity_check($regFile, $action, $regCache);

print "my \$initializer = BioMart::Initializer->new('registryFile'=>$regFile, 'action'=>$action)\n";
my $initializer = BioMart::Initializer->new('registryFile'=>$regFile, 'action'=>$action);
my $registry    = $initializer->getRegistry;
my $orgDataset  = `cat $regCache`;

my @class   = @{getOrgInfo("class")};
my %orglist = %{getOrgInfo("orglist")};
my $org_count = 0;
foreach my $class (@class) {
	my ($family) = $class =~ /^(\w+)\_\w+/;
	my $MainOrganism   = getMainOrganism($family);
	next if $family =~ /Prot/; # Protists are not used
	
	foreach my $org (@{$orglist{$class}}) {
		next if $orgDataset !~ /$org/i;
		next if $MainOrganism =~ /$org/i;
		$org_count++;
		print STDERR "$org_count\. Processing: $class.$org.ortholog\n";
		my $query = BioMart::Query->new('registry'=>$registry,'virtualSchemaName'=>'default');
		#$query->listDataset();
		$query->setDataset("$MainOrganism");
		$query->addAttribute("ensembl_gene_id");
		$query->addAttribute("$org\_homolog_ensembl_gene") if $MainOrganism =~ /gene_ensembl/;
		$query->addAttribute("$org\_eg_gene") if $MainOrganism =~ /eg_gene/;
		$query->addAttribute("$org\_eg_homolog_perc_id") if $MainOrganism =~ /eg_gene/;
		$query->addAttribute("$org\_homolog_perc_id") if $MainOrganism =~ /gene_ensembl/;

		$query->formatter("TSV"); # Tab Separated Values
		
		# Run Query
		my $query_runner = BioMart::QueryRunner->new();
		$query_runner->uniqueRowsOnly(1);# to obtain unique rows only
		$query_runner->execute($query);

		# Print Result
		open (OUT, ">", "$class\.$org.ortholog") or next;
		$query_runner->printHeader(\*OUT);
		$query_runner->printResults(\*OUT);
		$query_runner->printFooter(\*OUT);
	}
}

sub sanity_check {
	my ($regFile, $action, $regCache) = @_;
	my $errorMsg = "";
	if (not defined($regFile) or not -e $regFile) {
		$errorMsg .= "Cannot find registry file -r $regFile\n";
	}
	if (not defined($regCache) or not -e $regCache) {
		$errorMsg .= "Cannot find cached registry file $regCache\n";
	}
	if ($action ne "cached" and $action ne "clean") {
		$errorMsg .= "Cache (-c) must be either cached or clean\n";
	}
	die $errorMsg if $errorMsg !~ /^$/;

} 
sanity_check($regFile, $action, $regCache);


sub getMainOrganism {
	my ($family) = @_;
	return "athaliana_eg_gene" 	if $family =~ /Plant/i;
	return "dmelanogaster_eg_gene" 	if $family =~ /Metazoa/i;
	return "hsapiens_gene_ensembl" 	if $family =~ /Chordate/i;
	return "scerevisiae_eg_gene" 	if $family =~ /Fungi/i;
	print "Cannot find MainOrganism for family $family.
List of valid families:
- Plant
- Metazoa
- Chordate
- Fungi
";
}

sub getOrgInfo {
        my ($query) = @_;
        my @martlist = qw(ensembl metazoa fungi plants protists);

	my %name;
        my %org;

	# All organisms are ordered by NCBI taxa ID.
	my @class = qw(
	Protists_Fornicata Protists_Cryptophyta Plants_Rhodophyta Protists_Amoebozoa 
	Protists_Kinetoplastida Protists_Stramenopiles Protists_Alveolata 
	Plants_Chlorophyta Plants_Bryophyta Plants_Lycopodiophyta Plants_Eudicotyledons Plants_Liliopsida 
	Fungi_Tremellales Fungi_Ustilaginales Fungi_Eukaryota Fungi_Pucciniales Fungi_Schizosaccharomycetales Fungi_Saccharomycetales 
	Fungi_Pezizales Fungi_Capnodiales Fungi_Pleosporales Fungi_Eurotiales Fungi_Erysiphales Fungi_Sclerotiniaceae Fungi_Sordiales
	Fungi_Magnaporthales Fungi_Glomerellales Fungi_Hypocreales
	Metazoa_Porifera Metazoa_Placozoa Metazoa_Cnidaria Metazoa_Platyhelminthes Metazoa_Mollusca Metazoa_Annelida
	Metazoa_Nematoda Metazoa_Chelicerata Metazoa_Myriapoda Metazoa_Crustacea Metazoa_Phthiraptera Metazoa_Hemiptera 
	Metazoa_Coleoptera Metazoa_Hymenoptera Metazoa_Lepidoptera Metazoa_Diptera Metazoa_Echinodermata 
	Chordate_Tunicates Chordate_Agnatha Chordate_Osteichthyes Chordate_Amphibia Chordate_Reptilia Chordate_Aves 
	Chordate_Prototheria Chordate_Marsupialia Chordate_Xenartha 
	Chordate_Afrotheria Chordate_Laurasiatheria Chordate_Rodents Chordate_Primates
	);

	# Protists
	@{$org{Protists_Fornicata}}      = qw(glamblia);
	@{$org{Protists_Cryptophyta}}    = qw(gtheta);
	@{$org{Plants_Rhodophyta}}       = qw(cmerolae);
	@{$org{Protists_Amoebozoa}}      = qw(ddiscoideum ehistolytica);
	@{$org{Protists_Kinetoplastida}} = qw(tbrucei lmajor);
	@{$org{Protists_Stramenopiles}}  = qw(tpseudonana ptricornutum alaibachii pultimum harabidopsidis pramorum psojae pinfestans);
	@{$org{Protists_Alveolata}}      = qw(tthermophila ptetraurelia tgondii pfalciparum pvivax pknowlesi pchabaudi pberghei);

	# Plants
	@{$org{Plants_Chlorophyta}}    = qw(creinhardtii);
	@{$org{Plants_Bryophyta}}      = qw(ppatens);
	@{$org{Plants_Lycopodiophyta}} = qw(smoellendorffii);
	@{$org{Plants_Eudicotyledons}} = qw(stuberosum slycopersicum vvinifera brapa alyrata athaliana ptrichocarpa mtruncatula gmax);
	@{$org{Plants_Liliopsida}}     = qw(macuminata sitalica zmays sbicolor oglaberrima obrachyantha osativa oindica bdistachyon atauschii turartu hvulgare);
	
	# Fungi
	@{$org{Fungi_Tremellales}}     		= qw(cneoformans);
	@{$org{Fungi_Ustilaginales}}   		= qw(sreilianum umaydis);
	@{$org{Fungi_Eukaryota}}      		= qw(mviolaceum);
	@{$org{Fungi_Pucciniales}}     		= qw(mlaricipopulina ptriticina pgraminis);
	@{$org{Fungi_Schizosaccharomycetales}}  = qw(spombe);
	@{$org{Fungi_Saccharomycetales}}        = qw(ylipolytica agossypii scerevisiae kpastoris);
	@{$org{Fungi_Pezizales}} 	        = qw(tmelanosporum);
	@{$org{Fungi_Capnodiales}} 	        = qw(ztritici);
	@{$org{Fungi_Pleosporales}} 	        = qw(pnodorum lmaculans pteres ptriticirepentis);
	@{$org{Fungi_Eurotiales}} 		= qw(nfischeri afumigatus afumigatusa1163 anidulans aterreus aoryzae aniger aflavus aclavatus);
	@{$org{Fungi_Erysiphales}}		= qw(bgraminis);
	@{$org{Fungi_Sclerotiniaceae}} 		= qw(bfuckeliana ssclerotiorum);
	@{$org{Fungi_Sordiales}} 		= qw(ncrassa);
	@{$org{Fungi_Magnaporthales}} 		= qw(ggraminis moryzae mpoae);
	@{$org{Fungi_Glomerellales}} 		= qw(ggraminicola);
	@{$org{Fungi_Hypocreales}} 		= qw(treesei tvirens gmonilliformis gzeae nhaematococca foxysporum gmoniliformis);

	# Metazoa
	@{$org{Metazoa_Porifera}} 	 = qw(aqueenslandica);
	@{$org{Metazoa_Placozoa}} 	 = qw(tadhaerens);
	@{$org{Metazoa_Cnidaria}} 	 = qw(nvectensis);
	@{$org{Metazoa_Platyhelminthes}} = qw(smansoni);
	@{$org{Metazoa_Mollusca}} 	 = qw(lgigantea cgigas);
	@{$org{Metazoa_Annelida}} 	 = qw(cteleta hrobusta);
	@{$org{Metazoa_Nematoda}} 	 = qw(tspiralis ppacificus lloa bmalayi cjaponica cbrenneri cremanei celegans cbriggsae);
	@{$org{Metazoa_Chelicerata}} 	 = qw(turticae iscapularis);
	@{$org{Metazoa_Myriapoda}} 	 = qw(smaritima);
	@{$org{Metazoa_Crustacea}} 	 = qw(dpulex);
	@{$org{Metazoa_Phthiraptera}} 	 = qw(phumanus);
	@{$org{Metazoa_Hemiptera}} 	 = qw(rprolixus apisum);
	@{$org{Metazoa_Coleoptera}}	 = qw(tcastaneum);
	@{$org{Metazoa_Hymenoptera}}	 = qw(nvitripennis acephalotes amellifera);
	@{$org{Metazoa_Lepidoptera}}	 = qw(bmori hmelpomene dplexippus);
	@{$org{Metazoa_Diptera}} 	 = qw(adarlingi agambiae cquinquefasciatus aaegypti mscalaris dgrimshawi dvirilis dmojavensis dwillistoni dpseudoobscura dpersimilis dananassae dyakuba dsimulans dsechellia dmelanogaster derecta);
	@{$org{Metazoa_Echinodermata}} 	 = qw(spurpuratus);

	# Chordates
	@{$org{Chordate_Tunicates}}	 = qw(csavignyi cintestinalis);
	@{$org{Chordate_Agnatha}}	 = qw(pmarinus);
	@{$org{Chordate_Osteichthyes}}	 = qw(drerio gmorhua oniloticus tnigroviridis trubripes gaculeatus olatipes xmaculatus lchalumnae);
	@{$org{Chordate_Amphibia}}	 = qw(xtropicalis);
	@{$org{Chordate_Reptilia}}	 = qw(acarolinensis psinensis);
	@{$org{Chordate_Aves}} 		 = qw(aplatyrhynchos falbicollis tguttata mgallopavo ggallus);
	@{$org{Chordate_Prototheria}}	 = qw(oanatinus);
	@{$org{Chordate_Marsupialia}} 	 = qw(mdomestica meugenii sharrisii);
	@{$org{Chordate_Xenartha}} 	 = qw(dnovemcinctus choffmanni);
	@{$org{Chordate_Afrotheria}} 	 = qw(pcapensis lafricana etelfairi);
	@{$org{Chordate_Laurasiatheria}} = qw(ecaballus pvampyrus mlucifugus saraneus eeuropaeus vpacos btaurus sscrofa ttruncatus fcatus mfuro amelanoleuca cfamiliaris);
	@{$org{Chordate_Rodents}} 	 = qw(tbelangeri ocuniculus oprinceps cporcellus itridecemlineatus dordii rnorvegicus mmusculus);
	@{$org{Chordate_Primates}}	 = qw(ogarnettii mmurinus tsyrichta cjacchus mmulatta nleucogenys pabelii hsapiens ptroglodytes ggorilla);

	return(\@class)		if $query =~ /^class$/;
        return(\%org) 		if $query =~ /^orglist$/;
}
