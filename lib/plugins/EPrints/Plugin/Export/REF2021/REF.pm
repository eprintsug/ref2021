package EPrints::Plugin::Export::REF2021::REF;

# HEFCE REF Export - Abstract class
#
# generic class that can take REF1a/b/c and REF2 data and initialise the appropriate data structures prior to exporting to CSV, XML, ...

use EPrints::Plugin::Export;

@ISA = ( "EPrints::Plugin::Export" );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "REF2021 - Abstract Exporter class";
	$self->{accept} = [ 'report2021/ref1a', 'report2021/ref1b', 'report2021/ref1c', 'report2021/ref2' ];
	$self->{advertise} = 0;
	$self->{enable} = 1;
	$self->{visible} = 'staff';

	return $self;
}


sub initialise_fh
{
        my( $plugin, $fh ) = @_;

        binmode($fh, ":utf8" );

	# seems a bit hacky but that's the right place to send some extra HTTP headers - this one will tell the browser which files to save this report as.

	my $filename = ($plugin->{report}||'report')."_".EPrints::Time::iso_date().($plugin->{suffix}||".txt");

        EPrints::Apache::AnApache::header_out(
                      $plugin->{session}->get_request,
                      "Content-Disposition" => "attachment; filename=$filename"
        ); 
}

# Turns a REF2021 (EPrints) subject id into:
# 1- the HEFCE code for the UoA
# 2- whether this is part of a multiple submission or not

# multiple submissions:
# ref2021_a1 AND ref2021_a1b exist -> 'A', 'B'
sub parse_uoa
{
        my( $plugin, $uoa_id ) = @_;

        my ( $hefce_uoa_id, $is_multiple );
	
	# multiple submission: on EPrints, those UoAs are encoded with an extra 'b' ('bis') at the end e.g. ref2021_a1b for A1
        if( $uoa_id =~ /^ref2021_(\w)(\d+)(\w?)$/ )
        {
                $hefce_uoa_id = $2;
                # $is_multiple = EPrints::Utils::is_set( $3 );
		if( EPrints::Utils::is_set( $3 ) )
		{
			$is_multiple = 'B';
		}
		# it might still be a multiple submission ('A')
		if( !defined $is_multiple )
		{
			if( defined $plugin->{session}->dataset( 'subject' )->dataobj( $uoa_id."b" ) )
			{
				$is_multiple = 'A';
			}
		}
        }
        
        return( $hefce_uoa_id, $is_multiple );
}

# Extracts the UoA from different types of data objects. Exporters (XML, CSV...) need to know the UoA since it's a field for REF.
sub get_current_uoa
{
	my( $plugin, $object ) = @_;

	my $report = $plugin->get_report() or return undef;
	return undef unless( EPrints::Utils::is_set( $report ) );

	## technically, if we're viewing an old benchmark, a user UoA might not be set anymore :-( So we must get the info from somewhere else (and that is from one former ref_selection object)
	if( $report =~ /^ref1[abc]$/ )	# ref1a, ref1b, ref1c
	{
		# $object is EPrints::DataObj::User
		my $uoa = $object->value( 'ref2021_uoa' );
		if( defined $uoa )
		{
			return $uoa;
		}
		if( defined $plugin->{benchmark} )	# && !defined $uoa
		{
			# we might get it from one selection object
			my $selections = $plugin->{benchmark}->user_selections( $object );
			my $record = $selections->item( 0 );
			if( defined $record )
			{
				return $record->current_uoa();
			}
		}
	}
	elsif( $report eq 'ref2' || $report eq 'ref4' )
	{
		# $object is EPrints::DataObj::REF2021Selection
		return $object->current_uoa();
	}

	return undef;
}

# Which report are we currently exporting? values are set by the calling Screen::Report plugin and are: ref1a, ref1b, ref1c and ref2
sub get_report { shift->{report} }

# Generating a Report usually requires a few data objects (because data's stored in different places in EPrints).
sub get_related_objects
{
	my( $plugin, $dataobj ) = @_;

	my $report = $plugin->get_report();
	return {} unless( EPrints::Utils::is_set( $report ) && defined $dataobj );

	my $objects = {};
	my $session = $plugin->{session};

	if( $report =~ /^ref1[abc]$/ )	# ref1a, ref1b, ref1c
	{
		# we receive a user object and need to give back a "ref circumstance" object
	        $objects = {
        	        user => $dataobj,
                	ref2021_circ => EPrints::DataObj::REF2021Circ->new_from_user( $session, $dataobj->get_id ),
	        };
	}
	elsif( $report eq 'ref2' )
	{
		# we receive a ref_selection object, and need to give back a user & eprint object
                $objects = {
                        ref2021_selection => $dataobj,
                        user => $session->dataset( 'user' )->dataobj( $dataobj->value( 'user_id' ) ),
                };
                my $eprint = $session->dataset( 'eprint' )->dataobj( $dataobj->value( 'eprint_id' ) );
                $objects->{eprint} = $eprint if( defined $eprint );
	}

	return $objects;
}

# Returns a list of (HEFCE/REF) fields in the order expected by HEFCE. The defaults are defined in the local configuration (zz_ref_reports.pl)
sub ref_fields_order
{
	my( $plugin ) = @_;

	return $plugin->{ref_fields_order} if( defined $plugin->{ref_fields_order} );

	my $report = $plugin->get_report();
	return [] unless( defined $report );

	$plugin->{ref_fields_order} = $plugin->{session}->config( 'ref2021', $report, 'fields' );

	return $plugin->{ref_fields_order};
}

# Returns mappings between HEFCE/REF fields and EPrints' own fields. Look in zz_ref_reports.pl for more explanation on how this works.
sub ref_fields
{
	my( $plugin ) = @_;

	return $plugin->{ref_fields} if( defined $plugin->{ref_fields} );

	my $report = $plugin->get_report();
	return [] unless( defined $report );

	$plugin->{ref_fields} = $plugin->{session}->config( 'ref2021', $report, 'mappings' );

	return $plugin->{ref_fields};
}

1;
