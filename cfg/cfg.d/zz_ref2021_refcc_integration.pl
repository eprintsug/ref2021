$c->{is_compliant} = sub {
    
	my ( $repo, $dataobj ) = @_;

    my $eprint = $dataobj;

    if(ref($dataobj) =~ /REFSelection/ || ref($dataobj) =~ /REF2021Selection/){
        $eprint = $repo->dataset( 'eprint' )->dataobj( $dataobj->value( 'eprint_id' ) );

    }

    return $repo->html_phrase("hoa_compliance_marker_".$repo->call( "eprint_is_compliant", $repo, $eprint ));
};

#This one is also called directly from  zz_ref_reports.pl as per the mappings structure
$c->{eprint_is_compliant} = sub {

	my( $repo, $dataobj ) = @_;

    my $flag = $dataobj->value("hoa_compliant");	

    my $type = $dataobj->value( "type" );

	unless( defined $type && grep( /^$type$/, @{$repo->config( "hefce_oa", "item_types" )} ) )
	{		
		return "N/A";
	}

	#print compliance
	my $compliance = "N";
    if ( $flag & HefceOA::Const::COMPLIANT )
    {
            $compliance = "Y";
    }elsif( $flag & HefceOA::Const::DEP &&
            $flag & HefceOA::Const::DIS &&
            $flag & HefceOA::Const::ACC_EMBARGO &&
            $repo->call( ["hefce_oa", "could_become_ACC_TIMING_compliant"], $repo, $dataobj ) ){
    #handle future compliance with an "F"
        $compliance = "F";             
    }

    return $compliance;
};

package EPrints::Script::Compiled;
no warnings qw(redefine);

#Can be called on either an eprint or a ref_selection object
sub run_is_compliant
{
	my( $self, $state, $dataobj ) = @_;

	if( !defined $dataobj->[0] || (ref($dataobj->[0]) ne "EPrints::DataObj::EPrint" && ref($dataobj->[0]) ne "EPrints::DataObj::REFSelection" && ref($dataobj->[0]) ne "EPrints::DataObj::REF2021Selection") )
	{
		$self->runtime_error( "Can only call is_compliant on eprint or ref_selection objects not ".
			ref($dataobj->[0]) );
	}

	if( !$state->{session}->get_repository->can_call( "is_compliant" ) )
	{
		return [ undef, "STRING" ];
	}

	return [ $state->{session}->get_repository->call( "is_compliant", $state->{session}, $dataobj->[0] ), "XHTML" ]; 
}


