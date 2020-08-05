package CONFIG;

=head1 B<Input hash for BistQ>

=over 5

=item DESCRIPTION:

 BistQ input parameter CONFIG file.
    %c = (
        testbedAlias => "IN_VIJAY",      # check in DB,alias Exisists, SA or HA Pair(format), create OBJ to each Device in Alias and see its reachable 
        storeLogs => 1,                  # to specify where to store logs. 0(none), 1 (on SBX), 2 (on ATS), 3 (on both ATS and SBX)
        fipsmode => 0,                   # 0- nothing or 1 -enable --default 0--- optional
        tmsUpdate => 0,                  # 0- not to update results on TMS, 1 - update results on TMS
        coredumpLevel => "normal",       # "sensitive" or "normal", in iSMART 'sensitive' is default value 
        functionalArea => ["MISC"],      # functional area to run all the suites listed under the functional group
        testbedType => ["misc"],         # Testbed Type
        excludeVersion => ["V03.02.03"], # Suites matching this version can be excluded from running
        suites => ['AM1','AM2'],         # to run listed suites
        testCase => ["354398","354411"], # Testcases level control, will help debug single testcases , 
        mailTo => ["vmusigeri"],         # this list is used to send mails and also used for watcher's list for jira issue
        jobPriority => "normal",         # 'normal' or 'high'. only make it 'high' if you want to run this as high priority.
        suiteReady  => "Y",              # N- suite is not ready , Y- suite is ready for execution, I- suite InProgress
	regressionFlag => "P3",          # P1: Mandatory to regress; P2: Regress when dependent features are impacted; P3: Not P1 or P2; use when expanded coverage is required
        variant => "PSX_KVM_GSX",        # Variant for the execution
        jenkinsStream => "optional"      # TOOLS-78260: Optional jenkins stream name 
    );

=item PACKAGE:

 None

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=back

=cut

%c = ( 
        testbedAlias => "IN_VIJAY",    # check in DB,alias Exisists, SA or HA Pair(format), create OBJ to each Device in Alias and see its reachable 
        storeLogs => 1,                 # to specify where to store logs. 0(none), 1 (on SBX), 2 (on ATS), 3 (on both ATS and SBX)
        fipsmode => 0,                          # 0- nothing or 1 -enable --default 0--- optional
        tmsUpdate => 0,                 # 0- not to update results on TMS, 1 - update results on TMS
        coredumpLevel => "normal", # "sensitive" or "normal", in iSMART 'sensitive' is default value 
        functionalArea => ["MISC"], #functional area to run all the suites listed under the functional group
        testbedType => ["misc"],  #Testbed Type
        excludeVersion => ["V03.02.03"], #Suites matching this version can be excluded from running
        suites => ['AM1','AM2'], #to run listed suites
        testCase => ["354398","354411"], #Testcases level control, will help debug single testcases ,
        excludeTestcase => ["359613","359615"], # List of Testcases to be excluded from execution
        mailTo => ["vmusigeri"], #this list is used to send mails and also used for watcher's list for jira issue
        jobPriority => "normal", # 'normal' or 'high'. only make it 'high' if you want to run this as high priority.
        suiteReady  => "Y", # N- suite is not ready , Y- suite is ready for execution, I- suite InProgress
        regressionFlag => "P3", # P1: Mandatory to regress; P2: Regress when dependent features are impacted; P3: Not P1 or P2; use when expanded coverage is required
	variant => "PSX_KVM_GSX",
        jenkinsStream => "" # TOOLS-78260: Optional jenkins stream name 
     );
