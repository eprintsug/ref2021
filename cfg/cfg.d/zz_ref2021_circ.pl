#
# EPrints Services - REF2021 Package
#
# Version: 1.3
#

# REF2021 Staff Circumstances dataset

# called when a ref_selection object is committed
$c->{set_ref2021_circ_automatic_fields} = sub {
	my( $circ ) = @_;

	my $session = $circ->get_session;

	unless( $circ->is_set( 'circ' ) )
	{
		if( $circ->is_set( 'is_ecr' ) && $circ->get_value( 'is_ecr' ) eq 'TRUE' )
		{
			$circ->set_value( 'circ', '1' );
		}
	}

	if( $circ->is_set( 'is_fixed_term' ) && !$circ->is_set( 'fixed_term_start' ) )
	{
		# if the user's on a fixed-term contract, let's pre-populate the contract start date with $user->value( 'ref_start_date' )
		my $user = $circ->user();
		if( $user->is_set( 'ref_start_date' ) )
		{
			$circ->set_value( 'fixed_term_start', $user->get_value( 'ref_start_date' ) );
		}
	}
};

{
no warnings;

package EPrints::DataObj::REF2021Circ;

@EPrints::DataObj::REF2021Circ::ISA = qw( EPrints::DataObj );

sub get_dataset_id { "ref2021_circ" }

sub get_url { shift->uri }

sub get_defaults
{
	my( $class, $session, $data, $dataset ) = @_;

	$data = $class->SUPER::get_defaults( @_[1..$#_] );

	return $data;
}

sub get_control_url { $_[0]->{session}->config( "userhome" )."?screen=REF2021::EditCirc&circid=".$_[0]->get_id }

=item $list = EPrints::DataObj::REF2021Circ::search_by_user( $session, $user )

Returns the REF2021 Circumstance object belonging to $user

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

sub user
{
	my( $self ) = @_;

	return $self->{session}->dataset( 'user' )->dataobj( $self->get_value( 'userid' ) );
}

sub new_from_user
{
        my( $class, $session, $userid, $create_if_null ) = @_;

	$create_if_null = 0 unless( defined $create_if_null );

        my $circ = $session->dataset( $class->get_dataset_id )->search(
                filters => [
                        { meta_fields => [qw( userid )], value => $userid, match => "EX", },
                ],
        )->item( 0 );

	if( !defined $circ && $create_if_null )
	{
		# create a new one!
		return $class->create_from_data( $session, {
			userid => $userid,
		} );
	}	

	return $circ;
}

sub commit
{
	my( $self, $force ) = @_;

	unless( $self->is_set( 'datestamp' ) )
	{
		$self->set_value( 'datestamp', EPrints::Time::get_iso_timestamp() );
	}

	# this will call set_ref_selection_automatic_fields
	$self->update_triggers();

        if( scalar( keys %{$self->{changed}} ) == 0 )
        {
                # don't do anything if there isn't anything to do
                return( 1 ) unless $force;
        }

	$self->set_value( 'lastmod', EPrints::Time::get_iso_timestamp() );

	return $self->SUPER::commit( $force );
}


} # end of package

$c->{datasets}->{ref2021_circ} = {
	class => "EPrints::DataObj::REF2021Circ",
	sqlname => "ref2021_circ",
	name => "ref2021_circ",
	columns => [qw( circid )],
	index => 1,
	import => 1,
	search => {                
		simple => {
                        search_fields => [{
                                id => "q",
                                meta_fields => [qw(
					circid
                                )],
                        }],
                        order_methods => {
                                "byuserid"         =>  "userid",
                        },
                        default_order => "byuserid",
                        show_zero_results => 1,
                        citation => "result",
                },
        },
};

$c->{fields}->{ref2021_circ} = [] if !defined $c->{fields}->{ref2021_circ};
unshift @{$c->{fields}->{ref2021_circ}}, (
		{ name => "circid", type=>"counter", required=>1, can_clone=>0,
                        sql_counter=>"circid" }, 
        
	        { name=>"userid", type=>"itemref",
                        datasetid=>"user", required=>1, show_in_html=>0 },		

	        # not sure these 2 datestamp/lastmod fields are actually useful here:
		{ name => "datestamp", type=>"timestamp", required=>0, import=>0,
        	        render_res=>"minute", render_style=>"short", can_clone=>0 },
	        { name => "lastmod", type=>"timestamp", required=>0, import=>0,
        	        render_res=>"minute", render_style=>"short", can_clone=>0 },

		# circumstanceIdentifier
		{ name => 'circ', type => 'set', options => [ 1, 2, 3, 4, 5, 6, 7 ] },

		# CircumstanceExplanation
		{ name => 'circ_text', type => 'longtext' },
	
		# isEarlyCareerResearcher
		{ name => 'is_ecr', type => 'boolean' },
		# earlyCareerStartDate 
		{ name => 'ecr_start', type => 'date' },

		# isOnFixedTermContract
		{ name => 'is_fixed_term', type => 'boolean' },
		# contractStartDate
		{ name => 'fixed_term_start', type => 'date' },
		# contractEndDate
		{ name => 'fixed_term_end', type => 'date' },

		# isOnSecondment
		{ name => 'is_secondment', type => 'boolean' },
		# secondmentStartDate
		{ name => 'secondment_start', type => 'date' },
		# secondmentEndDate
		{ name => 'secondment_end', type => 'date' },

		# isOnUnpaidLeave
		{ name => 'is_unpaid_leave', type => 'boolean' },
		# unpaidLeaveStartDate
		{ name => 'unpaid_leave_start', type => 'date' },
		# unpaidLeaveEndDate
		{ name => 'unpaid_leave_end', type => 'date' },

		# isReseachFellow
		{ name => 'is_fellow', type => 'boolean' },
		# isNonUKBased
		{ name => 'is_non_uk', type => 'boolean' },
		# nonUKBasedText
		{ name => 'non_uk_text', type => 'longtext' },
		# totalPeriodOfAbsence
		{ name => 'absence', type => 'float' },
		# numberOfQualifyingPeriods

		# qualifyingPeriods
		{ name => 'qual_periods', type => 'int' },
		# complexOutputReduction
		{ name => 'complex_reduction', type => 'set', options => [ 0, 1, 2, 3 ] },

		# Cat C Circumstances (only to be shown if user.ref_category = 'C')
		
		# employingOrganisation
		{ name => 'catc_org', type => 'text' },
		# jobTitle
		{ name => 'catc_jobtitle', type => 'text' },
		# explanatoryText
		{ name => 'catc_text', type => 'longtext' },
);

1;
