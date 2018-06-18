#
# EPrints Services - REF Package
#
# Version: 1.3
#

# This file contains the code for doing data validation + data export


# Used by REF2021::Report::Listing to pre-populate the list of available reports (and their order):
$c->{'ref2021'}->{'reports'} = [] if !defined $c->{'ref2021'}->{'reports'};
unshift @{$c->{'ref2021'}->{'reports'}}, ( 'REF1a', 'REF1b', 'REF1c', 'REF2' );


##################
# DATA VALIDATION 
##################

# REF2


$c->{'ref2021'}->{map_eprint_type} = sub {
	my( $eprint ) = @_;

	my $type = $eprint->value( 'type' ) or return;

	if( $type eq 'book' )
	{
		return 'B' if !$eprint->is_set( 'creators' );	# Edited book
		return 'A';					# Authored book
	}

	return 'M' if $type eq 'exhibition';
	return 'C' if $type eq 'book_section';			# Chapter in book
	return 'D' if $type eq 'article'; 			# Journal article
	return 'E' if $type eq 'conference_item'; 		# Conference contribution
	return 'F' if $type eq 'patent'; 			# Patent / published patent application
        return 'I' if $type eq 'performance';                   # Performance
        return 'J' if $type eq 'composition';                   # Composition
        return 'L' if $type eq 'artefact';                      # Artefact
        return 'Q' if $type eq 'video';                         # Digital or visual media
        return 'T' if $type eq 'other';                         # Other

	return undef;
};

# optional fields: do not show a validation warning if those fields are not defined
$c->{'ref2021'}->{eprint_optional_map} = {map { $_ => 1 } qw(
	R_publisher
	P_publisher
	N_publisher
	Q_publisher
	R_isbn
	E_issn
	A_doi
	B_doi
	C_doi
	R_doi
	E_doi
	N_doi
	S_doi
	T_doi
	A_url
	B_url
	C_url
	R_url
	D_url
	E_url
	L_url
	P_url
	M_url
	I_url
	F_url
	N_url
	K_url
	J_url
	Q_url
	S_url
	G_url
	T_url
)};

$c->{'ref2021'}->{ref2_validate_fields} = sub {
	my( $repo, $selection, $eprint, $problems ) = @_;	#?? 
	
    if( !defined $eprint )
	{
		$eprint = $repo->eprint( $selection->value( "eprint_id" ) );
	}
	if( !defined $eprint )
	{
		push @$problems, $repo->html_phrase( "ref2021:validate:bad_eprint" );
		return {};
	}

	if( $eprint->is_set( 'eprint_status' ) && $eprint->value( 'eprint_status' ) ne 'archive' )
	{
		push @$problems, $repo->html_phrase( "ref2021:validate:eprint_not_live" );
	}

	my $type = $selection->value( 'type' );

	unless( defined $type )
	{
		$type = $repo->call( [ 'ref2021', 'map_eprint_type' ], $eprint );
	}

	if( !defined $type )
	{
		$type = 'T'; # we need type for other choices
		push @$problems, $repo->html_phrase( "ref2021:validate:bad_type",
			eprint_type => $repo->make_text( $eprint->value( "type" ) )
		);
		return {};
	}

	my %ref;
	$ref{output_type} = $type;

	# Output Title
	if( $type =~ /[AB]/ )
	{
		$ref{output_title} = $eprint->value( "book_title" ) || $eprint->value( 'title' );
	}
	else
	{
		$ref{output_title} = $eprint->value( "title" );
	}

	# Place
	if( $type =~ /[LPMIST]/ )
	{
		$ref{place} = $eprint->value( "place_of_pub" );
	}
	elsif( $type =~ /[MI]/ )
	{
		$ref{place} = $eprint->value( "event_location" );
	}
	elsif( $type =~ /[NO]/ )
	{
		# TODO Commissioning body
	}

	# Publisher
	if( $type =~ /[ABCRNQG]/ )
	{
		$ref{publisher} = $eprint->value( "publisher" );
	}
	# TODO P - Manufacturer

	# Volume title
	if( $type =~ /[CR]/ )
	{
		$ref{volume_title} = $eprint->value( "book_title" );
	}
	elsif( $type =~ /[D]/ )
	{
		$ref{volume_title} = $eprint->value( "publication" );
	}
	elsif( $type =~ /[E]/ )
	{
		$ref{volume_title} = $eprint->value( "event_title" );
	}

	# Article number
	if( $type =~ /[D]/ )
	{
		# TODO $ref{article_number} = $eprint->value( "" );
	}

	# Volume
	if( $type =~ /[DE]/ )
	{
		$ref{volume} = $eprint->value( "volume" );
	}

	# Issue
	if( $type =~ /[DE]/ )
	{
		$ref{issue} = $eprint->value( "number" );
	}

	# First page
	if( $type =~ /[DE]/ )
	{
		no warnings; # undef
		($ref{first_page}) = split '-', $eprint->value( "pagerange" );
	}

	# ISBN
	if( $type =~ /[ABCR]/ )
	{
		$ref{isbn} = $eprint->value( "isbn" );
	}

	# ISSN
	if( $type =~ /[DE]/ )
	{
		$ref{issn} = $eprint->value( "issn" );
	}

	# DOI
	if( $type =~ /[ABCRDENST]/ )
	{
		$ref{doi} = $eprint->value( "id_number" );
		undef $ref{doi}
			if defined $ref{doi} && $ref{doi} !~ /^(doi:)?10\.\d\d\d\d\//;
	}

	# Patent Number
	if( $type =~ /[F]/ )
	{
		$ref{patent_number} = $eprint->value( "id_number" );
	}

	# Year
	{
		no warnings;
		$ref{year} = substr($eprint->value( "date" ),0,4);
	}

	# URL
	{
		$ref{url} = $eprint->value( "official_url" );
	}

	# Media of Output
	if( $type =~ /[LPMIKJQSHGT]/ )
	{
		$ref{media_of_output} = $eprint->value( "output_media" );
	}
    
    if($repo->can_call("eprint_is_compliant") && $eprint->exists_and_set("hoa_compliant")){

        my $compliance = $repo->call( "eprint_is_compliant", $repo, $eprint) ;
        if( $compliance eq 'N' )
        {
            push @$problems, $repo->html_phrase( "ref2021:validate:not_oa_compliant",
                ref_cc_link => $repo->render_link($eprint->get_control_url."&ep_eprint_view_current=6", "_new" ) 
            );
        }
        if( $compliance eq 'F' )
        {

			push @$problems,  $repo->html_phrase( "report_future_compliant", last_foa_date => $repo->xml->create_text_node( $repo->call( [ "hefce_oa", "calculate_last_compliant_foa_date" ], $repo, $eprint )->strftime( "%Y-%m-%d" ) ) );

        }
    }

	my $optional_map = $repo->config( 'ref', 'eprint_optional_map' ) || {};
	my $fields_length = $repo->config( 'ref', 'ref2_fields_length' ) || {};
	foreach my $key (sort keys %ref)
	{
		# field length
		if( defined $fields_length->{$key} && defined $ref{$key} )
		{
			my $maxlen = $fields_length->{$key};
			my $curlen = length( $ref{$key} );
			if( $curlen > $maxlen )
			{
				my $desc = ( $repo->dataset( 'eprint' )->has_field( $key ) ) ? $repo->html_phrase( "eprint_fieldname_$key" ) : $repo->make_text( $key );
				push @$problems, $repo->html_phrase( 'ref2021:validate:char_limit', fieldname => $desc, maxlen => $repo->make_text( $maxlen ) );
			}
		}

		next if defined $ref{$key};
		next if $optional_map->{"${type}_${key}"};

		my $desc = ( $repo->dataset( 'eprint' )->has_field( $key ) ) ? $repo->html_phrase( "eprint_fieldname_$key" ) : $repo->make_text( $key );

		push @$problems, $repo->html_phrase( "ref2021:validate:missing_field",
			fieldname => $desc );
	}

	return \%ref;
};

# in characters
$c->{'ref2021'}->{'ref2_fields_length'} = {
	place => 256,
	publisher => 256,
	volume_title => 256,
	volume => 16,
	issue => 16,
	first_page => 8,
	isbn => 24,
	issn => 24,
	doi => 256,
	patent_number => 24,
	media_of_output => 24,

};


$c->{plugins}->{"Screen::REF2021::Report::REF2"}->{params}->{validate_selection} = sub {
	my( $user, $selection, $eprint, $ctx ) = @_;

	my $session = $user->{session};

	my @problems;

	if( $selection->is_set( "details" ) )
	{
		my @words = split /\s+/, $selection->value( "details" );
		if( @words > 300 )
		{
			push @problems, $session->html_phrase( "ref2021:validate:word_limit",
				field => $selection->{dataset}->field( "details" )->render_name( $session ),
				length => $session->make_text( scalar @words ),
				limit => $session->make_text( 300 ),
			);
		}
	}
	if( $selection->is_set( "abstract" ) )
	{
		my @words = split /\s+/, $selection->value( "abstract" );
		if( @words > 100 )
		{
			push @problems, $session->html_phrase( "ref2021:validate:word_limit",
				field => $selection->{dataset}->field( "abstract" )->render_name( $session ),
				length => $session->make_text( scalar @words ),
				limit => $session->make_text( 100 ),
			);
		}
	}

	if( $selection->is_set( 'reserve' ) )
	{
		# can't have chosen a reserved output if the current selection is not double-weighted
		if( !$selection->is_set( 'weight' ) || $selection->get_value( 'weight' ) ne 'double' )
		{
			push @problems, $session->html_phrase( "ref2021:validate:wrong_reserve" );
		}
	
		# a selection can't be double-weighted and a reserved for itself
		if( $selection->get_value( 'reserve' ) eq $selection->get_id )
		{
			push @problems, $session->html_phrase( "ref2021:validate:self_reserve" );
		}

	}
	else
	{
		# if the output is double weighted then it must reference a reserved output
		if( $selection->is_set( 'weight' ) && $selection->value( 'weight' ) eq 'double' )
		{
			push @problems, $session->html_phrase( "ref2021:validate:missing_field",
					fieldname => $session->html_phrase( 'ref_selection_fieldname_reserve' )
			);

		}
	}
	
	# if the output is double-weighted then must provide a statement
	if( $selection->is_set( 'weight' ) && $selection->value( 'weight' ) eq 'double' && !$selection->is_set( 'weight_text' ) ) 
	{
                push @problems, $session->html_phrase( "ref2021:validate:missing_field",
                        fieldname => $session->html_phrase( 'ref_selection_fieldname_weight_text' )
                );	
	}

	# if the output is non-english, then must provide an English abstract
	if( $selection->is_set( 'non_english' ) && $selection->value( 'non_english' ) eq 'TRUE' && !$selection->is_set( 'abstract' ) )
	{
                push @problems, $session->html_phrase( "ref2021:validate:missing_field",
                        fieldname => $session->html_phrase( 'ref_selection_fieldname_abstract' )
                );
	}

	# if the output has conflicts of interest then must provide the list of the conflicted panel members
	if( $selection->is_set( 'has_conflicts' ) && $selection->value( 'has_conflicts' ) eq 'TRUE' && !$selection->is_set( 'conflicted_members' ) )
	{
                push @problems, $session->html_phrase( "ref2021:validate:missing_field",
                        fieldname => $session->html_phrase( 'ref_selection_fieldname_conflicted_members' )
                );
	}

	# if the output is non-english, then must provide an English abstract
	if( $selection->is_set( 'is_xref' ) && $selection->value( 'is_xref' ) eq 'TRUE' && !$selection->is_set( 'xref' ) )
	{
                push @problems, $session->html_phrase( "ref2021:validate:missing_field",
                        fieldname => $session->html_phrase( 'ref_selection_fieldname_xref' )
                );
	}

	# extra validation:
	$session->call( [ 'ref2021', 'ref2_validate_fields' ], $session, $selection, $eprint, \@problems );

	my $year = $eprint->value( "date" );
	$year = "" if !defined $year;
	$year = substr($year,0,4);

    if( !$year || $year < 2014 || $year > 2019 )
	{
		push @problems, $session->html_phrase( "ref2021:validate:year",
			year => $session->make_text( $year ),
		);
	}

	return @problems;
};



# REF1a

$c->{plugins}->{"Screen::REF2021::Report::REF1a"}->{params}->{validate_user} = sub {
	my( $user, $ctx ) = @_;

	my $session = $user->{session};

	my @problems;

	my $type = $user->value( 'ref_category' );

	unless( defined $type )
	{
		push @problems, { desc => $session->html_phrase( "ref2021:validate_user:no_category"), field => 'ref_category' };
		return @problems;	# can't go further, we must know the category
	}

	if( !( $type eq 'A' || $type eq 'C' ) )
	{
		push @problems, { desc => $session->html_phrase( "ref2021:validate_user:wrong_category") };
		return @problems;	# can't go further, we must know the category
	}

	# internal_id as in the Institution's unique id (employee id or else)
	my $mf = [ 'staff_id', 'name_family', 'name_given' ];

	if( $type eq 'A' )
	{
		push @$mf, ( 'hesa', 'dob', 'ref_fte' );
	}

	my $ds = $user->get_dataset;
	foreach( @$mf )
	{
		next unless( $ds->has_field( "$_" ) );

		unless( $user->is_set( "$_" ) )
		{
			push @problems, { field => $_, desc => $session->html_phrase( "ref2021:validate_user:missing_field", field => $ds->field( $_ )->render_name ) };
			next;
		}

		# FTE must be >= 0.2
		if( "$_" eq 'ref_fte' )
		{
			my $fte = $user->get_value( "$_");
			if( $fte < 0.2 )
			{
				push @problems, { field => 'ref_fte', desc => $session->html_phrase( "ref2021:validate_user:low_fte" ) };
			}
			elsif( $fte > 1.0 )
			{
				push @problems, { field => 'ref_fte', desc => $session->html_phrase( "ref2021:validate_user:high_fte" ) };
			}
		}

	}

	# Circumstances validation

	my $circ = EPrints::DataObj::REFCirc->new_from_user( $session, $user->get_id, 1 ); 
	return @problems unless( defined $circ );	# should never happen

	my $circds = $circ->dataset;
	foreach my $type ( 'fixed_term', 'secondment', 'unpaid_leave' )
	{
		my $is_mf = "is_$type";	# eg is_fixed_term, is_secondment ... (those fields are defined in zz_ref2021_circ.pl)

		next unless( $circ->exists_and_set( $is_mf ) );

		my $value = $circ->value( $is_mf );
		next if( $value ne 'TRUE' );
		
		# start and end dates must be defined

		foreach my $date ( 'start', 'end' )
		{
			my $date_mf = $type."_".$date;	# eg secondment_start ...
			if( !$circ->is_set( $date_mf ) )
			{
				push @problems, { field => $date_mf, desc => $session->html_phrase( "ref2021:validate_user:missing_field", field => $circds->field( $date_mf )->render_name ) };
			}
		}
	}

	if( $circ->is_set( 'circ' ) && !$circ->is_set( 'circ_text' ) )
	{
		push @problems, { field => 'circ_text', desc => $session->html_phrase( "ref2021:validate_user:missing_field", field => $circds->field( 'circ_text' )->render_name ) };
	}

	if( $circ->is_set( 'is_non_uk' ) && $circ->value( 'is_non_uk' ) eq 'TRUE' && !$circ->is_set( 'non_uk_text' ) )
	{
		push @problems, { field => 'non_uk_text', desc => $session->html_phrase( "ref2021:validate_user:missing_field", field => $circds->field( 'non_uk_text' )->render_name ) };
	}

	return @problems;
};

$c->{plugins}->{"Screen::REF2021::Report::REF1c"}->{params}->{validate_user} = sub {
	my( $user, $ctx ) = @_;

	my $session = $user->{session};

	my @problems;
	
	my $type = $user->value( 'ref_category' );
	my $circ = EPrints::DataObj::REFCirc->new_from_user( $session, $user->get_id, 1 );
	my $circds = $session->dataset( 'ref2021_circ' ); 
	
	# if staff is category C, must fill in the cat c circumstance fields:

	if( defined $type && $type eq 'C' )
	{
		foreach my $mf ( 'catc_org', 'catc_jobtitle', 'catc_text' )
		{
			next if( $circ->is_set( $mf ) );
			push @problems, { field => $mf, desc => $session->html_phrase( "ref2021:validate_user:missing_field", field => $circds->field( $mf )->render_name ) };
		}
	}

	return @problems;
};



##############
# DATA EXPORT
##############

#
# Notes on Mappings
#
# The mappings follow one of the two formats below:
#
#  1- HEFCE_FIELD_NAME => EPRINTS_DATASET_ID . EPRINTS_FIELD_NAME
#  2- HEFCE_FIELD_NAME => \&method
#
#  Method (1) example: "eprint.title" -> this will get the data from the relevant EPrint object, and it will return the "title" field value
#
#  Method (2) is a reference to a method (aka a sub' in PERL). The method will receive:
#  	a - the plugin object which is calling the sub (for instance Export::REF_XML)
#  	b - the relevant objects passed via a hash e.g. $objects->{eprint}
#	
#  Note that the sub can return "" or undef if they cannot parse or retrieve the appropriate data/values. If you intend on changing these or adding new subs, have a look at the existing ones below.
#


# REF1a Fields - fields defined by HEFCE for the REF1/a Report

$c->{'ref2021'}->{'ref1a'}->{'fields'} = [qw{ hesaStaffIdentifier staffIdentifier surname initials category birthDate contractedFte isResearchFellow isEarlyCareerResearcher startDate isOnFixedTermContract contractStartDate contractEndDate isOnSecondment secondmentStartDate secondmentEndDate isOnUnpaidLeave unpaidLeaveStartDate unpaidLeaveEndDate isNonUKBased nonUKBasedText isSensitive circumstanceExplanation }];

# REF1a Mappings

$c->{'ref2021'}->{'ref1a'}->{'mappings'} = {
	hesaStaffIdentifier => "user.hesa",
	staffIdentifier => "user.staff_id",
	surname => \&ref1a_surname,
	initials => \&ref1a_initials,
	category => "user.ref_category",
	birthDate => "user.dob",
	contractedFte => "user.ref_fte",
	isResearchFellow => "ref2021_circ.is_fellow",
	isEarlyCareerResearcher => "ref2021_circ.is_ecr",
	startDate => "user.ref_start_date",
	isOnFixedTermContract => "ref2021_circ.is_fixed_term",
	contractStartDate => "ref2021_circ.fixed_term_start",
	contractEndDate => "ref2021_circ.fixed_term_end",
	isOnSecondment => "ref2021_circ.is_secondment",
	secondmentStartDate => "ref2021_circ.secondment_start",
	secondmentEndDate => "ref2021_circ.secondment_end",
	isOnUnpaidLeave => "ref2021_circ.is_unpaid_leave",
	unpaidLeaveStartDate => "ref2021_circ.unpaid_leave_start",
	unpaidLeaveEndDate => "ref2021_circ.unpaid_leave_end",
	isNonUKBased => "ref2021_circ.is_non_uk",
	nonUKBasedText => "ref2021_circ.non_uk_text",
	isSensitive => "user.ref_is_sensitive",
	circumstanceExplanation => "ref2021_circ.circ_text",
	# + ResearchGroup[1|2|3|4]
};

{
    no warnings 'redefine';

    sub ref1a_surname
    {
        my( $plugin, $objects ) = @_;

        my $user = $objects->{user} or return;

        my $name = $user->value( 'name' ) or return;

        return $name->{family};
    }

    sub ref1a_initials
    {
        my( $plugin, $objects ) = @_;

        my $user = $objects->{user} or return;

        my $name = $user->value( 'name' ) or return;

        my $gname = $name->{given} or return;

        return uc( substr( $gname, 0, 1 ) ).".";
    }

};

# REF1b Fields - fields defined by HEFCE for the REF1/b Report

$c->{'ref2021'}->{'ref1b'}->{'fields'} = [qw{ hesaIdentifier staffIdentifier circumstanceIdentifier earlyCareerStartDate totalPeriodOfAbsence numberOfQualifyingPeriods complexOutputReduction }];

# REF1b Mappings

$c->{'ref2021'}->{'ref1b'}->{'mappings'} = {
	hesaStaffIdentifier => "user.hesa",
	staffIdentifier => "user.staff_id",
	circumstanceIdentifier => "ref2021_circ.circ",
	earlyCareerStartDate => "ref2021_circ.ecr_start",
	totalPeriodOfAbsence => "ref2021_circ.absence",
	numberOfQualifyingPeriods => "ref2021_circ.qual_periodes",
	complexOutputReduction => "ref2021_circ.complex_reduction",
};



# REF1c Fields - fields defined by HEFCE for the REF1/c Report

$c->{'ref2021'}->{'ref1c'}->{'fields'} = [qw{ hesaIdentifier staffIdentifier employingOrganisation jobTitle explanatoryText }];

# REF1c Mappings

$c->{'ref2021'}->{'ref1c'}->{'mappings'} = {
	hesaStaffIdentifier => "user.hesa",
	staffIdentifier => "user.staff_id",
	employingOrganisation => "ref2021_circ.catc_org",
	jobTitle => "ref2021_circ.catc_jobtitle",
	explanatoryText => "ref2021_circ.catc_text",
};




# REF2 Fields - fields defined by HEFCE for the REF2 Report

$c->{'ref2021'}->{'ref2'}->{'fields'} = [qw{ hesaStaffIdentifier staffIdentifier outputNumber outputIdentifier outputType title place publisher volumeTitle volume issue firstPage articleNumber isbn issn doi patentNumber year url mediaOfOutput numberOfAdditionalAuthors isPendingPublication isDuplicateOutput isNonEnglishLanguage isInterdisciplinary proposeDoubleWeighting doubleWeightingStatement reserveOutput hasConflictsOfInterests conflictedPanelMembers isOutputCrossReferred crossReferToUoa additionalInformation englishAbstract researchGroup isSensitive internalRating selfRating Departments OACompliant }];


# REF2 Mappings - how to extract the data and format it

$c->{'ref2021'}->{'ref2'}->{'mappings'} = { 

	"hesaStaffIdentifier" => "user.hesa",
	"staffIdentifier" => "user.staff_id",

	"outputNumber" => \&ref2_outputNumber,				# auto: 1..4
	"outputIdentifier" => "ref2021_selection.selectionid",		# ref2021_selection.selectionid
	"outputType" => "ref2021_selection.type",				# ref2021_selection.type
	"title" => "eprint.title",					# eprint.title
	"place" => "eprint.event_location",				# eprint.event_location
	"publisher" => "eprint.publisher",				# eprint.publisher?
	"volumeTitle" => \&ref2_volumeTitle,				# eprint.series / eprint.publication?
	"volume" => "eprint.volume",					# eprint.volume
	"issue" => "eprint.number",					# eprint.number
	"firstPage" => \&ref2_firstPage,				# eprint.pagerange
	"articleNumber" => \&ref2_article_number,			# will look up either eprints.article_number (note: not a default EPrints field) or ref2021_selection.article_id (added in v1.2.3)
	"isbn" => "eprint.isbn",					# eprint.isbn
	"issn" => "eprint.issn",					# eprint.issn
	"doi" => "eprint.id_number",					# eprint.id_number? only if type != patent
	"patentNumber" => \&ref2_patentNumber,				# eprint.id_number only if of type patent though!
	"year" => \&ref2_year,						# eprint.date_year
	"url" => \&ref2_url,						# auto: eprint.url
	"mediaOfOutput" => "eprint.output_media",			# eprint.output_media
	"numberOfAdditionalAuthors" => \&ref2_additionalAuthors,	# auto: scalar(@creators) - 1
	"isPendingPublication" => "ref2021_selection.pending",		# ref2021_selection.pending (bool)
	"isDuplicateOutput" => "ref2021_selection.duplicate",		# ref2021_selection.duplicate
	"isNonEnglishLanguage" => "ref2021_selection.non_english",		# ref2021_selection.non_english (bool)
	"isInterdisciplinary" => "ref2021_selection.interdis",		# ref2021_selection.interdis (bool)
	"proposeDoubleWeighting" => \&ref2_doubleWeighting	,	# ref2021_selection.weight
	"doubleWeightingStatement" => "ref2021_selection.weight_text",	# ref2021_selection.weight_text
	"reserveOutput" => "ref2021_selection.reserve",			# ref2021_selection.reserve
	"hasConflictsOfInterests" => "ref2021_selection.has_conflicts",	# ref2021_selection.has_conflicts
	"conflictedPanelMembers" => "ref2021_selection.conflicted_members",	# ref2021_selection.conflicted_members
	"isOutputCrossReferred" => "ref2021_selection.is_xref",		# ref2021_selection.is_xref (bool)
	"crossReferToUoa" => \&ref2_cross_ref,				# ref2021_selection.xref (subject)
	"additionalInformation" => "ref2021_selection.details",		# ref2021_selection.details
	"englishAbstract" => \&ref2_abstract,				# ref2021_selection.abstract || eprint.abstract
	"researchGroup" => "ref2021_selection.research_group",		# ref2021_selection.research_group
	"isSensitive" => "ref2021_selection.sensitive",			# ref2021_selection.sensitive (bool)
	"selfRating" => "ref2021_selection.self_rating",			# ref2021_selection.self_rating
	"Departments" => "eprint.divisions",			# eprint.divisions
	"OACompliant" => \&ref2_hoa_compliant,			# eprint.is compliant? Y/N/F (for future)

};

{
    no warnings 'redefine';

    # for REF2 the following objects are passed to the sub's:
    # 	$objects->{ref2021_selection} - the current REF Selection object
    #	$objects->{eprint}	  - the related EPrint object
    #	$objects->{user}	  - the related User object

    sub ref2_url
    {
        my( $plugin, $objects ) = @_;

        return $objects->{eprint}->get_url;
    }

    sub ref2_outputNumber
    {
        my( $plugin, $objects ) = @_;

        my $user = $objects->{user};
        my $key = $user->value( 'ref2021_uoa' )."-".$user->get_id;

        if( exists $plugin->{_cache}->{$key} )
        {
            $plugin->{_cache}->{$key}++;
        }
        else
        {
            $plugin->{_cache}->{$key} = 1;
        }

        return $plugin->{_cache}->{$key};
    }

    sub ref2_patentNumber
    {
        my( $plugin, $objects ) = @_;

        my $ref_selection = $objects->{ref2021_selection};
        my $eprint = $objects->{eprint};

        my $valid = 0;
        if( $ref_selection->is_set( 'type' ) )
        {
            $valid = 1 if( $ref_selection->value( 'type' ) eq 'F' );	# see HEFCE Output types
        }
        else
        {
            $valid = 1 if( $eprint->value( 'type' ) eq 'patent' );
        }

        if( $valid )
        {
            return $eprint->value( 'id_number' );
        }

        return undef;
    }

    sub ref2_year
    {
            my( $plugin, $objects ) = @_;
     
            my $eprint = $objects->{eprint};

            return substr($eprint->value( 'date' ), 0, 4);
    }

    sub ref2_additionalAuthors
    {
        my( $plugin, $objects ) = @_;

        my $co_authors = scalar( @{$objects->{eprint}->value( 'creators' ) || [] } ) - 1;

        return $co_authors > 0 ? "$co_authors" : "0";
    }

    sub ref2_doubleWeighting
    {
        my( $plugin, $objects ) = @_;

        my $weight = $objects->{ref2021_selection}->value( 'weight' );

        return ( defined $weight && $weight eq 'double' ) ? 'TRUE' : 'FALSE';
    }

    sub ref2_abstract
    {
        my( $plugin, $objects ) = @_;

        if( $objects->{ref2021_selection}->is_set( 'abstract' ) )
        {
            return $objects->{ref2021_selection}->value( 'abstract' ); 
        }

        return $objects->{eprint}->value( 'abstract' );
    }

    sub ref2_firstPage
    {
        my( $plugin, $objects ) = @_;

        return undef unless( $objects->{eprint}->is_set( 'pagerange' ) );

        my $pagerange = $objects->{eprint}->value( 'pagerange' );

        $pagerange =~ s/\-(.*)$//g;

        return $pagerange;
    }

    sub ref2_volumeTitle
    {
        my( $plugin, $objects ) = @_;

        # this will depend mostly on the Output type - refer to the Output requirements document produced by HEFCE
        
        my $ref_selection = $objects->{ref2021_selection};
        return undef unless( $ref_selection->is_set( 'type' ) );

        my $eprint = $objects->{eprint};

        my $type = $ref_selection->value( 'type' );

        if( $type eq 'C' )
        {
            # C - Chapter in book => Book title
            return $eprint->value( 'book_title' );
        }
        elsif( $type eq 'R' )
        {
            # R - Scholarly edition => title of edition
            return $eprint->value( 'series' );
        }
        elsif( $type eq 'D' )
        {
            # D - Journal article => title of journal
            return $eprint->value( 'publication' );
        }	
        elsif( $type eq 'E' )
        {
            # E - Conference contribution => name of conference / published proceedings
            return $eprint->value( 'series' );
        }

        return undef;
    }

    sub ref2_cross_ref
    {
        my( $plugin, $objects ) = @_;

        my $ref_selection = $objects->{ref2021_selection};

        my $uoa_id = $ref_selection->value( 'xref' ) or return;
            if( $uoa_id =~ /^ref2021_(\w)(\d+)(b?)$/ )
            {               
            return $2;
            }

        return undef;
    }

    sub ref2_article_number
    {
        my( $plugin, $objects ) = @_;

        my $eprint = $objects->{eprint};
        
        # not a default EPrints field but some institutions may have added it
        if( defined $eprint && $eprint->exists_and_set( 'article_number' ) )
        {
            return $eprint->value( 'article_number' );
        }

        # added in v1.2.3
        return $objects->{ref2021_selection}->value( 'article_id' );
    }

    #Check for compliance NB: requires REF CC plugin to be installed
    sub ref2_hoa_compliant
    {

        my( $plugin, $objects ) = @_;

        my $eprint = $objects->{eprint};
        my $flag = $eprint->value("hoa_compliant");	
        my $repo = $plugin->{session};
        
        if($repo->can_call("eprint_is_compliant")){
            return $repo->call( "eprint_is_compliant", $repo, $eprint )
        }
        return undef;
    }
};

1;


