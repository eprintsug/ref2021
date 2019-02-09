package EPrints::Plugin::Export::REF2021::REF_CSV;

# HEFCE Generic Exporter to CSV 

use EPrints::Plugin::Export::REF2021::REF;
@ISA = ( "EPrints::Plugin::Export::REF2021::REF" );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "REF2021 - CSV";
	$self->{suffix} = ".csv";
	$self->{mimetype} = "text/csv; charset=utf-8";
	$self->{advertise} = 1;

	return $self;
}

sub output_list
{
	my( $self, %opts ) = @_;

	my $fields =[qw/institution unitOfAssessment multipleSubmission action/];
	push @{$fields}, @{$self->ref_fields_order()};

	$opts{fields} = $fields;
	$self->{benchmark} = $opts{benchmark};

	my @r;
	my $f = $opts{fh} ? sub { print {$opts{fh}} $_[0] } : sub { push @r, $_[0] };

	#write the header row
	&$f(csv( @{$fields} ));

	# list of things
	my $repo = $self->{session};
	my $institution = $repo->config( 'ref2021', 'institution' ) || $repo->phrase( 'archive_name' );
	my $action = $repo->config( 'ref2021', 'action' ) || 'Update';

	# common fields/values
	$opts{commons} = {
		institution => $institution,
		action => $action,
	};

	$opts{list}->map( sub {
		( undef, undef, my $item ) = @_;

		&$f($self->output_dataobj( $item, %opts ));
	} );

	return join '', @r;
}
sub output_dataobj
{
	my( $self, $dataobj, %opts ) = @_;

	my $row = $self->REF_to_row( $dataobj, %opts );

	my @r;
	push @r, csv( @{$row} );

	return join '', @r;
}

sub csv
{
	my( @row ) = @_;

	my @r = ();
	foreach my $item ( @row )
	{
		if( !defined $item )
		{
			push @r, '';
		}
		else
		{
			$item =~ s/"/""/g;
			$item =~ s/[\n\r\t]//g;
			push @r, "=\"$item\"" if $item =~ /^\d+$/;
			push @r, "\"$item\"" if $item !~ /^\d+$/;
		}
	}

	return join( ",", @r )."\r\n";
}

# Exports a single object / line. For CSV this must also includes the first four "common" fields.
sub REF_to_row
{
	my( $plugin, $dataobj, %opts ) = @_;

	my $session = $plugin->{session};
	return "" unless( $session->config( 'ref2021_enabled' ) );

	my $commons = $opts{commons};

	my $ref_fields = $plugin->ref_fields();

	my $objects = $plugin->get_related_objects( $dataobj );

	my @values;
	my $uoa_id = $plugin->get_current_uoa( $dataobj );
	return "" unless( defined $uoa_id );	# abort!
	
	my ( $hefce_uoa_id, $is_multiple ) = $plugin->parse_uoa( $uoa_id );
	return "" unless( defined $hefce_uoa_id );

	my $valid_ds = {};
	foreach my $dsid ( keys %$objects )
	{
		$valid_ds->{$dsid} = $session->dataset( $dsid );
	}

	# first we need to output the first 4 fields (the 'common' fields)
	foreach( "institution", "unitOfAssessment", "multipleSubmission", "action" )
	{
		my $value;
		if( $_ eq 'unitOfAssessment' )	# get it from the ref_selection object
		{
			$value = $hefce_uoa_id;
		}
		elsif( $_ eq 'multipleSubmission' ) 
		{ 
			$value = $is_multiple || ""; 
		}
		else
		{
			$value = $commons->{$_};
		}
		if( EPrints::Utils::is_set( $value ) )
		{
			push @values,  $value;
		}
		else
		{
			push @values, "";
		}

	}

	# don't print out empty rows so check that something's been done:
	my $done_any = 0;
	foreach my $hefce_field ( @{$plugin->ref_fields_order()} )
	{
		my $ep_field = $ref_fields->{$hefce_field};
		if( ref( $ep_field ) eq 'CODE' )
		{
			# a sub{} we need to run
			eval {
				my $value = &$ep_field( $plugin, $objects );

				if( EPrints::Utils::is_set( $value ) )
				{
					push @values, $value ;
					$done_any++ 
				}
				else
				{
					push @values, "";
				}
			};
			if( $@ )
			{
				$session->log( "REF_CSV Runtime error: $@" );
			}

			next;
		}
		elsif( $ep_field !~ /^([a-z_0-9]+)\.([a-z_]+)$/ )
		{
			# wrong format :-/
			push @values, "";
			next;
		}

		# a straight mapping with an EPrints field
		my( $ds_id, $ep_fieldname ) = ( $1, $2 );
		my $ds = $valid_ds->{$ds_id};

		unless( defined $ds && $ds->has_field( $ep_fieldname ) )
		{
			# dataset or field doesn't exist
			push @values, "";
			next;
		}

		my $value = $objects->{$ds_id}->value( $ep_fieldname );
		$done_any++ if( EPrints::Utils::is_set( $value ) );

        #HAndle ARRAyS better (a bit)
        if( ref( $value ) eq 'ARRAY' ){
            my $multi = "";
            for my $item(@{$value}){
                $multi.=$item ."; ";
            }
            $multi =~ s/;$//g;
            push @values, $multi;

        }else{
            push @values, $value;
        }
	}

	return undef unless( $done_any );
	return \@values;
}

1;
