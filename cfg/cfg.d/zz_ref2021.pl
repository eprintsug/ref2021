#
# EPrints Services - REF Package
#
# Version: 1.3
#

# Bazaar Configuration
$c->{plugins}{"Export::REF2021::REF"}{params}{disable} = 0;
$c->{plugins}{"Export::REF2021::REF_XML"}{params}{disable} = 0;
$c->{plugins}{"Export::REF2021::REF_CSV"}{params}{disable} = 0;
$c->{plugins}{"Export::REF2021::REF_Excel"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF2021"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF2021::Edit"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF2021::Benchmark::Select"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF2021::Benchmark::Copy"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF2021::Benchmark::New"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF2021::Benchmark::LinkListing"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF2021::Benchmark::Destroy"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF2021::User::Edit"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF2021::User::EditUoA"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF2021::User::EditCirc"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF2021::User::EditCircLink"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF2021::User::EditCircLinkBack"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF2021::Listing"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF2021::Overview"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF2021::Report"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF2021::Report::Listing"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF2021::Report::REF1a"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF2021::Report::REF1b"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF2021::Report::REF1c"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF2021::Report::REF2"}{params}{disable} = 0;


# Main switch (used for 3.2 backport)
$c->{ref2021_enabled} = 1;

# The name of your institution (used by reports) - otherwise it will default to the Repository name
# $c->{'ref'}->{'institution'} = 'University of XYZ';

# The action that appears in the (exported) Reports (will default to 'Update');
# $c->{'ref'}->{'action'} = 'Update';

# Controls which reports a 'normal' (non-Champion) can view (see REF2021::Overview)
# available reports/data: ref/view/ref1a, ref/view/ref1b, ref/view/ref1c
push @{$c->{user_roles}->{user}}, qw{
	ref2021/view/ref2
};

push @{$c->{user_roles}->{editor}}, qw{
	ref2021/view/ref2
};

push @{$c->{user_roles}->{admin}}, qw{
	ref2021/view/ref2
};

# ref/edit/ref1abc controls the behaviour of REF2021::User::Edit and REF2021::User::EditCirc (which should be together really)
# ref/edit/ref2 is not implemented, it's actually controlled by ref/select (see REF2021::Listing)
#push @{$c->{user_roles}->{user}}, qw{
#	ref/edit/ref1abc
#};

# You may have a custom method that checks who can see the Listing and Overview screens
# The commented-out example below forbids anyone who doesn't have the ref/select role
# from seeeing their own selections (e.g. if they've been made on their behalf)
$c->{ref2021_can_user_view_listing} = sub {

	my( $session ) = @_;

	# let the uoa champion see the screen:
	return 1 if( $session->current_user->exists_and_set( 'ref2021_uoa_role' ) );

	return 1 if( $session->current_user->exists_and_set( 'ref2021_uoa' ) && $session->current_user->has_role( 'ref/select' ) );

	return 0;
};


# used for the dataobjref metafields (see dataset "ref2021_selection")
$c->{datasets}->{eprint}->{search}->{simple}->{meta_fields} = [ "title", "abstract" ];
$c->{datasets}->{user}->{search}->{simple}->{meta_fields} = [ "name", "username" ];


# Un-comment the line below to search publications by author id ( == user.email or == role.email ) rather than by author name
# $c->{'ref'}->{search_authored}->{by_id} = 1;

# by default the above option will map user.email to eprint.creators_id. But perhaps you'd like to use some other fields, in which case un-comment
# the following:
# $c->{'ref'}->{search_authored}->{by_id_fields} = {
#	user_field => userid,
#	eprint_field => creators_browse_id,
# };


# Sets the datasets to search on the REF2021::Listing screen. By default, it will only search "archive".
# If you want to search archive + buffer, change this to 'archive buffer'
# If you want to search archive + buffer + inbox, change this to 'archive buffer inbox'
$c->{'ref2021'}->{listing_search_datasets} = 'archive';

# Default search to run on the REF2021::Listing page (un-comment the one you want):
$c->{'ref2021'}->{default_search} = 'search_authored';	# items that the user has co-authored (2008 onwards)
#$c->{'ref'}->{default_search} = 'search_deposited';	# items that the user has deposited (2008 onwards)
#$c->{'ref'}->{default_search} = '';			# will show an empty search form


# If a user's UoA has changed, this will also update all the REF Selection objects referencing the pair (user,uoa)
$c->add_dataset_trigger( "user", EPrints::Const::EP_TRIGGER_AFTER_COMMIT, sub {
	my( %params ) = @_;

	my $repo = $params{repository};
	my $user = $params{dataobj};
	my $changed = $params{changed};
	my $uoa_id = $changed->{ref2021_uoa};

	return if !defined $uoa_id;
	return if !$user->is_set( "ref2021_uoa" );

	my $benchmark = EPrints::DataObj::REFBenchmark->default( $repo );
	return if !defined $benchmark;

	$benchmark->user_selections( $user )->map(sub {
		(undef, undef, my $selection) = @_;

		$selection->unselect_for( $benchmark );
		$selection->select_for( $benchmark, $user->value( "ref2021_uoa" ) );
		$selection->{non_volatile_change} = 0;
		$selection->commit;
	});
});

# called when a ref2021_selection object is committed
$c->{set_ref2021_selection_automatic_fields} = sub {
	my( $selection ) = @_;

	my $session = $selection->get_session;

	# Re-sync the EPrint title while we're here
	my $eprint = $session->dataset( 'eprint' )->dataobj( $selection->value( 'eprint_id' ) );

	if( defined $eprint )
	{
		$selection->set_value( 'eprint_title', $eprint->value( 'title' ) );

		unless( $selection->is_set( 'type' ) )
		{
			# see zz_ref_report.pl for $c->{ref2021}->{map_eprint_type}
			$selection->set_value( 'type', $session->call( [ 'ref2021', 'map_eprint_type' ], $eprint ) );
		}
	}
};

# If the title of an EPrint changes, we need to update the REF Selection objects
$c->add_dataset_trigger( "eprint", EPrints::Const::EP_TRIGGER_AFTER_COMMIT, sub {
	my( %params ) = @_;

	my $repo = $params{repository};
	my $eprint = $params{dataobj};
	my $changed = $params{changed};
	my $new_title = $changed->{title} or return;

	$repo->dataset( 'ref2021_selection' )->search(
		filters => [ { 
			meta_fields => [ 'eprint_id' ], 
			value => $eprint->get_id
	} ] )->map( sub {
		my( undef, undef, $selection ) = @_;

		$selection->set_value( 'eprint_title', $new_title );
		$selection->commit;
	} );
});


# 
# REF Selection object
#

{
no warnings 'redefine';

package EPrints::DataObj::REF2021Selection;

@EPrints::DataObj::REF2021Selection::ISA = qw( EPrints::DataObj );

sub get_dataset_id { "ref2021_selection" }

sub get_url { shift->uri }

sub get_defaults
{
	my( $class, $session, $data, $dataset ) = @_;

	$data = $class->SUPER::get_defaults( @_[1..$#_] );

	$data->{weight} = "single";
	$data->{lastmod} = $data->{datestamp} = EPrints::Time::get_iso_timestamp();

	return $data;
}

sub get_control_url { $_[0]->{session}->config( "userhome" )."?screen=REF2021::Edit&selectionid=".$_[0]->get_id }

=item $selection = EPrints::DataObj::REF2021Selection::create_from_parts( $session, %parts )

Creates a new REF2021 Selection object based on the %parts (eprint,user, user_actual objects)

=cut
sub create_from_parts
{
	my( $class, $session, %parts ) = @_;

	my( $eprint, $user, $user_actual ) = @parts{qw( eprint user user_actual )};

	return $class->create_from_data( $session, {
		eprint => {
			id => $eprint->id,
			title => $session->xhtml->to_text_dump( $eprint->render_description ),
		},
		user => {
			id => $user->id,
			title => $session->xhtml->to_text_dump( $user->render_description ),
		},
		user_actual => {
			id => $user_actual->id,
			title => $session->xhtml->to_text_dump( $user_actual->render_description ),
		},
	});
}

=item $selection = EPrints::DataObj::REF2021Selection::new_from_parts( $session, %parts )

Instanciates an existing REF2021 Selection object based on the provided %parts (eprint,user, user_actual objects)

=cut
sub new_from_parts
{
	my( $class, $session, %parts ) = @_;

	my( $eprint, $user, $user_actual ) = @parts{qw( eprint user user_actual )};

	return $session->dataset( $class->get_dataset_id )->search(
		filters => [
			{ meta_fields => [qw( eprint_id )], value => $eprint->id, match => "EX", },
			{ meta_fields => [qw( user_id )], value => $user->id, match => "EX", },
		],
	)->item( 0 );
}

=item $list = EPrints::DataObj::REF2021Selection::search_by_user( $session, $user )

Returns the REF2021 Selection objects belonging to $user

=cut
sub search_by_user
{
	my( $class, $session, $user ) = @_;

	return $session->dataset( $class->get_dataset_id )->search(
		filters => [
			{ meta_fields => [qw( user_id )], value => $user->id, match => "EX", },
		],
	);
}

=item $list = EPrints::DataObj::REF2021Selection::search_by_eprint( $session, $eprint )

Returns the REF2021 Selection objects attached to the $eprint object

=cut
sub search_by_eprint
{
	my( $class, $session, $eprint ) = @_;

	return $class->search_by_eprintid( $session, $eprint->get_id );

	return $session->dataset( $class->get_dataset_id )->search(
		filters => [
			{ meta_fields => [qw( eprint_id )], value => $eprint->id, match => "EX", },
		],
	);
}

=item $list = EPrints::DataObj::REF2021Selection::search_by_eprintid( $session, $eprint )

Returns the REF2021 Selection objects attached to $eprintid

=cut
sub search_by_eprintid
{
	my( $class, $session, $eprintid ) = @_;

	return $session->dataset( $class->get_dataset_id )->search(
		filters => [
			{ meta_fields => [qw( eprint_id )], value => $eprintid, match => "EX", },
		],
	);
}


=item $arrayref = EPrints::DataObj::REF2021Selection::who_selected( $session, $eprint )

Returns a list of user IDs who have selected the $eprintid for REF2021

=cut
sub who_selected
{
        my( $class, $session, $eprintid ) = @_;

        my $list = $class->search_by_eprintid( $session, $eprintid );

        my @userids;

        # extract all userids from REF2021Selection objects:
        $list->map( sub { push @{$_[3]->{userids}}, $_[2]->get_value( "user_id" ) }, { userids => \@userids } );

        return \@userids;
}



=item $selection->select_for( $benchmark, $uoa_id )

Add this selection to the given benchmark for the given UoA.

=cut
sub select_for
{
	my( $self, $benchmark, $uoa_id ) = @_;

	foreach my $ref (@{$self->value( "ref" )})
	{
		return if $ref->{benchmarkid} == $benchmark->id;
	}
	
	$self->set_value( "ref", [
		@{$self->value( "ref" )},
		{ uoa => $uoa_id, benchmarkid => $benchmark->id },
	]);
}

=item $selection->unselect_for( $benchmark )

Remove this selection from the given benchmark.

=cut
sub unselect_for
{
	my( $self, $benchmark ) = @_;

	my @ref;
	foreach my $ref (@{$self->value( "ref" )})
	{
		push @ref, $ref if $ref->{benchmarkid} != $benchmark->id;
	}

	$self->set_value( "ref", \@ref );
}

sub current_uoa
{
	my( $self ) = @_;

	my $bm = EPrints::DataObj::REF2021Benchmark->default( $self->{session} );

	return undef if !defined $bm;

	return $self->uoa( $bm );
}

=item $uoa = $selection->uoa( $benchmark )

Returns the UoA this selection is being submitted to, for the given benchmark.

=cut
sub uoa
{
	my( $self, $benchmark ) = @_;

	foreach my $ref (@{$self->value( "ref" )})
	{
		return $ref->{uoa} if $ref->{benchmarkid} == $benchmark->id;
	}

	return undef; # oops
}

sub commit
{
	my( $self, $force ) = @_;

	unless( $self->is_set( 'datestamp' ) )
	{
		$self->set_value( 'datestamp', EPrints::Time::get_iso_timestamp() );
	}

	# this will call set_ref2021_selection_automatic_fields
	$self->update_triggers();

        if( scalar( keys %{$self->{changed}} ) == 0 )
        {
                # don't do anything if there isn't anything to do
                return( 1 ) unless $force;
        }

	if( !$self->{non_volatile_change} )
	{
		$self->set_value( 'lastmod', EPrints::Time::get_iso_timestamp() );
	}

	return $self->SUPER::commit( $force );
}

sub get_warnings
{       
        my( $self , $for_archive ) = @_;
	
	# validation of the ref2021_selection object

	return [];
}

} # end of package


# REF2021 Selection Dataset definition

$c->{datasets}->{ref2021_selection} = {
	class => "EPrints::DataObj::REF2021Selection",
	sqlname => "ref2021_selection",
	name => "ref2021_selection",
	columns => [qw( selectionid userid eprintid userid_actual )],
	index => 1,
	import => 1,
	search => {                
		simple => {
                        search_fields => [{
                                id => "q",
                                meta_fields => [qw(
					selectionid
					userid
                                        eprintid
					userid_actual
                                )],
                        }],
                        order_methods => {
                                "byuserid"         =>  "-eprintid/userid",
                                "byeprintid"        =>  "userid/eprintid",
                        },
                        default_order => "byuserid",
                        show_zero_results => 1,
                        citation => "result",
                },
        },
};


# REF2021 Selection Fields definition

# internal fields
$c->add_dataset_field( 'ref2021_selection', { name => "selectionid", type=>"counter", required=>1, can_clone=>0, sql_counter=>"selectionid" }, reuse => 1 );
# user who made the selection
$c->add_dataset_field( 'ref2021_selection',  { name => "user", type=>"dataobjref", required=>1, datasetid=>"user", fields => [ { sub_name => 'title', type => 'text' } ]}, reuse => 1 );
# selected eprint
$c->add_dataset_field( 'ref2021_selection', { name => "eprint", type=>"dataobjref", required=>1, datasetid=>"eprint",fields=>[ { sub_name => 'title', type => 'text' } ]}, reuse => 1 );
# user for whom the selection has been made (can be the same as 'user' above)
$c->add_dataset_field( 'ref2021_selection', { name => "user_actual", type=>"dataobjref", required=>1, datasetid=>"user",fields=>[ { sub_name => 'title', type => 'text' } ]}, reuse => 1 );
# when this selection was made
$c->add_dataset_field( 'ref2021_selection', { name => "datestamp", type=>"timestamp", required=>0, import=>0, render_res=>"minute", render_style=>"short", can_clone=>0 }, reuse => 1 );
# when this selection was last modified
$c->add_dataset_field( 'ref2021_selection', { name => "lastmod", type=>"timestamp", required=>0, import=>0, render_res=>"minute", render_style=>"short", can_clone=>0 }, reuse => 1 );
# a compound referencing the benchmark this selection is made against, as well as its UoA
$c->add_dataset_field( 'ref2021_selection', {
			name => "ref",
			type => "compound",
			multiple => 1,
			fields => [
				{ sub_name => "benchmarkid", type => "itemref", datasetid => "ref2021_benchmark", },
				{ sub_name => "uoa", type => "subject", top => "ref2021_uoas", },
			],
		}, reuse => 1 );
# outputType
$c->add_dataset_field( 'ref2021_selection',	{ name => "type", type=>"set", options=>[qw( A B C D E F G H I J K L M N O P Q R S T U )], }, reuse => 1 );
# outputNumber: not actually used - the number's set automatically
$c->add_dataset_field( 'ref2021_selection', { name => "position", type => "int", }, reuse => 1 );
# isInterdisciplinary
$c->add_dataset_field( 'ref2021_selection', { name => "interdis", type => "boolean" },reuse => 1 );
# crossReferToUoa
$c->add_dataset_field( 'ref2021_selection', { name => "xref", type => "subject", top => "ref2021_uoas", }, reuse => 1 );
# isOutputCrossReferred
$c->add_dataset_field( 'ref2021_selection', { name => "is_xref", type => 'boolean' }, reuse => 1 );
# additionalInformation
$c->add_dataset_field( 'ref2021_selection', { name => "details", type => "longtext" }, reuse => 1 );
# englishAbstract - should be copied from the eprint?
$c->add_dataset_field( 'ref2021_selection', { name => "abstract", type => "longtext" }, reuse => 1 );
# not sure this is the right format for proposeDoubleWeighting (this seems a cross between proposeDoubleWeighting and reserveOutput)
$c->add_dataset_field( 'ref2021_selection', { name => "weight", type => "set", options => [qw( single double )], required => 1 }, reuse => 1 );
# doubleWeightingStatement
$c->add_dataset_field( 'ref2021_selection', { name => "weight_text", type => "longtext" }, reuse => 1 );
# reserveOutput
$c->add_dataset_field( 'ref2021_selection', { name => "reserve", type => "set", options => [1,2,3,4] }, reuse => 1 );
# self rating - note: not submitted to REF2021
$c->add_dataset_field( 'ref2021_selection', { name => "self_rating", type => "set", options => [0, 1, 2, 3, 4] }, reuse => 1 );
# isPendingPublication
$c->add_dataset_field( 'ref2021_selection', { name => 'pending', type => 'boolean' }, reuse => 1 );
# isDuplicateOutput - this can be automatically set?
$c->add_dataset_field( 'ref2021_selection', { name => 'duplicate', type => 'boolean' }, reuse => 1 );
# isNonEnglishOutput
$c->add_dataset_field( 'ref2021_selection', { name => 'non_english', type => 'boolean' }, reuse => 1 );
# hasConflictsOfInterests
$c->add_dataset_field( 'ref2021_selection', { name => 'has_conflicts', type => 'boolean' }, reuse => 1 );
# conflictedPanelMembers
$c->add_dataset_field( 'ref2021_selection', { name => 'conflicted_members', type => 'longtext' }, reuse => 1 );
# isSensitive
$c->add_dataset_field( 'ref2021_selection', { name => 'sensitive', type => 'boolean' }, reuse => 1 );
# researchGroup (just a free form text, no validation done on it)
$c->add_dataset_field( 'ref2021_selection', { name => 'research_group', type => 'text', maxlength => 1 }, reuse => 1 );
# Article number
$c->add_dataset_field( 'ref2021_selection', { name => 'article_id', type => 'text' }, reuse => 1 );

# REF2021 Search Configuration (as used by REF2021::Listing)

$c->{search}->{"ref"} =
{
        search_fields => [
                { meta_fields => [ $EPrints::Utils::FULLTEXT ] },
                { meta_fields => [ "title" ] },
                { meta_fields => [ "creators_name" ] },
                { meta_fields => [ "abstract" ] },
                { meta_fields => [ "date" ] },
                { meta_fields => [ "keywords" ] },
                { meta_fields => [ "divisions" ] },
                { meta_fields => [ "subjects" ] },
                { meta_fields => [ "type" ] },
                { meta_fields => [ "editors_name" ] },
                { meta_fields => [ "ispublished" ] },
                { meta_fields => [ "refereed" ] },
                { meta_fields => [ "publication" ] },
                { meta_fields => [ "documents.format" ] },
                { meta_fields => [ "datestamp" ] },
        ],
        citation => "result",
        page_size => 20,
        order_methods => {
                "byyear"         => "-date/creators_name/title",
                "byyearoldest"   => "date/creators_name/title",
                "byname"         => "creators_name/-date/title",
                "bytitle"        => "title/creators_name/-date"
        },
        default_order => "byyear",
        show_zero_results => 1,
};


# returns an EPrints::List of User objects representing the user roles the given $user can assume
# note that you may build static list of users here
$c->{ref2021_roles_for_user} = sub
{
	my ( $session, $user ) = @_;
		
	my $list = EPrints::List->new(
		session => $session,
		dataset => $session->dataset( "user" ),
		ids => [],
	);

	if( $user->is_set( "ref2021_uoa_role" ) )
	{
		my $roles = $user->value( 'ref2021_uoa_role' );

		# sf2 - patch to make the Search works over Subject fields inside Compounds fields (fixed in 3.2.8)
		foreach( @$roles )
		{
			$list = $list->union( $session->dataset( "user" )->search(
	                        filters => [
        	                        { meta_fields => [qw( ref2021_uoa )], value => "$_", match => "EQ", merge => "ANY" },
                	        ],
	                ));
		}

	}
		
	return $list;
};


# User fields for REF2021

# date of birth
$c->add_dataset_field( 'user', { name => 'dob', type => 'date' }, reuse => 1 );
# HESA Identifier
$c->add_dataset_field( 'user', { name => 'hesa', type => 'id' }, reuse => 1 );
# (internal) Staff Identifier
$c->add_dataset_field( 'user', { name => 'staff_id', type => 'id' }, reuse => 1 );
# REF2021 Staff Category
$c->add_dataset_field( 'user', { name => 'ref_category', type => 'set', options => [ 'A', 'C' ] }, reuse => 1 );
# REF2021 Start dates
$c->add_dataset_field( 'user', { name => 'ref_start_date', type => 'date' }, reuse => 1 );
# REF2021 End dates (not used) - removed in v1.2
# $c->add_dataset_field( 'user', { name => 'ref_end_date', type => 'date' }, reuse => 1 );
# FTE
$c->add_dataset_field( 'user', { name => 'ref_fte', type => 'float' }, reuse => 1 );
# Unit of Assessment
$c->add_dataset_field( 'user', { name => 'ref2021_uoa', type => 'subject', top => 'ref2021_uoas' }, reuse => 1 );
# UoA Champion
$c->add_dataset_field( 'user', { name => 'ref2021_uoa_role', type => 'subject', top => 'ref2021_uoas', multiple => 1 }, reuse => 1 );
# isSensitive
$c->add_dataset_field( 'user', { name => 'ref_is_sensitive', type => 'boolean' }, reuse => 1 );


1;
