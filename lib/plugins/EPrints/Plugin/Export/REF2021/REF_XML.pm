package EPrints::Plugin::Export::REF2021::REF_XML;

# HEFCE Generic Exporter to XML

use EPrints::Plugin::Export::REF2021::REF;
@ISA = ( "EPrints::Plugin::Export::REF2021::REF" );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "REF2021 - XML";
	$self->{suffix} = ".xml";
	$self->{mimetype} = "text/xml";
        $self->{advertise} = $self->{enable} = EPrints::Utils::require_if_exists( "HTML::Entities" ) ? 1:0;

	return $self;
}

# sf2 / multipleSubmission is not in the XML template so that field is not currently exported (see http://www.ref.ac.uk/media/ref/content/subguide/3.ExampleImportFile.xml)
sub output_list
{
        my( $plugin, %opts ) = @_;

        my $list = $opts{list};
	my $session = $plugin->{session};

	my $institution = $plugin->escape_value( $session->config( 'ref2021', 'institution' ) || $session->phrase( 'archive_name' ) );
	my $action = $session->config( 'ref2021', 'action' ) || 'Update';

	# anytime we change to another UoA we need to regenerate a fragment of XML (<submission> etc...)
	my $current_uoa = undef;

	# the tags for opening/closing eg <outputs><output/></outputs> (ref2) or <staff><staffMember/></staff> (ref1abc)

	my( $main_tag, $secondary_tag ) = $plugin->tags;

	unless( defined $main_tag && defined $secondary_tag )
	{
		$session->log( "REF_XML error - missing tags for report ".$plugin->get_report );
		return;		
	}

print <<HEADER;
<?xml version="1.0" encoding="utf-8"?>
<ref2021Data xmlns="http://www.ref.ac.uk/schemas/ref2021data">
	<institution>$institution</institution>
	<submissions>
HEADER

	$opts{list}->map( sub {
		my( undef, undef, $dataobj ) = @_;

		my $uoa = $plugin->get_current_uoa( $dataobj );
		return unless( defined $uoa );

		if( !defined $current_uoa || ( "$current_uoa" ne "$uoa" ) )
		{

			my( $hefce_uoa_id, $is_multiple ) = $plugin->parse_uoa( $uoa );

			return unless( defined $hefce_uoa_id );

			my $multiple = "";
			if( EPrints::Utils::is_set( $is_multiple ) )
			{
				$multiple = "<multipleSubmission>$is_multiple</multipleSubmission>";
			}

			if( defined $current_uoa )
			{
				print <<CLOSING;
			</$main_tag>
		</submission>
CLOSING
			}

			print <<OPENING;
		<submission>
			<unitOfAssessment>$hefce_uoa_id</unitOfAssessment>
			$multiple
			<$main_tag>

OPENING
			$current_uoa = $uoa;
		}
		my $output = $plugin->output_dataobj( $dataobj );
		return unless( EPrints::Utils::is_set( $output ) );
		print "<$secondary_tag>\n$output\n</$secondary_tag>\n";
	} );


	if( defined $current_uoa ) # i.e. have we output any records?
	{
		print <<CLOSING;
			</$main_tag>
		</submission>
CLOSING
	}

print <<FOOTER;
	</submissions>
</ref2021Data>
FOOTER

}

sub tags
{
	my( $plugin ) = @_;

	my $report = $plugin->get_report;
	return () unless( defined $report );

	my $main;
	my $secondary;
	if( $report =~ /^ref1[abc]$/ )
	{
		$main = 'staff';
		$secondary = 'staffMember';
	}
	elsif( $report eq 'ref2' )
	{
		$main = 'outputs';
		$secondary = 'output';
	}
	return () unless( defined $main && defined $secondary );
	
	return( $main, $secondary );
}


# Note that undef/NULL values will not be included in the XML output
sub output_dataobj
{
	my( $plugin, $dataobj ) = @_;

	my $session = $plugin->{session};

	my $ref_fields = $plugin->ref_fields();

	my $objects = $plugin->get_related_objects( $dataobj );
	return "" unless( EPrints::Utils::is_set( $objects ) );
	
	my $valid_ds = {};
	foreach my $dsid ( keys %$objects )
	{
		$valid_ds->{$dsid} = $session->dataset( $dsid );
	}

	my @values;
	my @catc_values;	# REF1c is a bit of a funny one
	foreach my $hefce_field ( @{$plugin->ref_fields_order()} )
	{
		my $ep_field = $ref_fields->{$hefce_field};

		if( ref( $ep_field ) eq 'CODE' )
		{
			eval {
				my $value = &$ep_field( $plugin, $objects );
				next unless( EPrints::Utils::is_set( $value ) );
				push @values, "<$hefce_field>".$plugin->escape_value( $value )."</$hefce_field>";
			};
			if( $@ )
			{
				$session->log( "REF_XML: Runtime error: $@" );
			}

			next;
		}
		elsif( $ep_field =~ /^([a-z_]+)\.([a-z_]+)$/ )	# using an object field to extract data from
		{
			my( $ds_id, $ep_fieldname ) = ( $1, $2 );
			my $ds = $valid_ds->{$ds_id};

			next unless( defined $ds && $ds->has_field( $ep_fieldname ) );

			my $value = $objects->{$ds_id}->value( $ep_fieldname ) or next;

            if( ref( $value ) eq 'ARRAY' ){
                my $multi = "<$hefce_field>";
                for my $item(@{$value}){
                    $multi.="<item>".$plugin->escape_value( $item )."</item>";
                }
                $multi .="</$hefce_field>";

                push @values, $multi;

            }else{

                # hacky you said?... well the Cat C fields need to have their own enclosure (I don't see the point but heh)
                if( $ep_field =~ /^ref_circ\.catc_/ )
                {
                    push @catc_values, "<$hefce_field>".$plugin->escape_value( $value )."</$hefce_field>";
                }
                else
                {
                    push @values, "<$hefce_field>".$plugin->escape_value( $value )."</$hefce_field>";
                }
            }
		}
	}

	if( scalar( @catc_values ) )
	{
		push @values, "<categoryCCircumstances>\n".join( "\n", @catc_values )."</categoryCCircumstances>";
	}

	return join( "\n", @values );
}

sub escape_value
{
	my( $plugin, $value ) = @_;

	return undef unless( EPrints::Utils::is_set( $value ) );

	return HTML::Entities::encode_entities( $value, "<>&" );
}

1;
