///////////////////////////////////////////////////////////////////////////////
//  File name : s28hs256m4.sv
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
//  Copyright (C) 2024 Infineon Technologies Memory Solution, LLC.
//
//  MODIFICATION HISTORY :
//
//  version: |   author:     |  mod date:  |  changes made:
//    V1.0     A. Avanindra    18 July 2024      Inital Release
//    V2.0     A. Avanindra    11 May  2025      Verification fixes for CRC and other issues 
//    V3.0     A. Abdullah     04 Nov  2025      More Verification updates
//    V4.0     A. Avanindra    03 Feb  2026      ASP features support
//    
///////////////////////////////////////////////////////////////////////////////
//  PART DESCRIPTION:
//
//  Library:    FLASH
//  Technology: FLASH MEMORY
//  Part:       S28HS256M4
//
//  Description: 256 Megabit Floating Gate NOR Flash Memory
//
//////////////////////////////////////////////////////////////////////////////
//  Comments :
//      For correct simulation, simulator resolution should be set to 1 ps
//      A device ordering (trim) option determines whether a feature is enabled
//      or not, or provide relevant parameters:
//        -15th character in TimingModel determines if enhanced high
//         performance option is available
//            (0,2) General Market
//
//////////////////////////////////////////////////////////////////////////////
//  Known Bugs:
//
//////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////
// MODULE DECLARATION                                                       //
//////////////////////////////////////////////////////////////////////////////
`timescale 1 ps/1 ps

module s28hs256m4
    (
        // Data Inputs/Outputs
        SI     ,
        SO     ,
        DQ3    ,
        DQ2    ,
        // Controls
        SCK    ,
        CSNeg  ,
        DS     ,
        RESETNeg,
        INTNeg
    );

///////////////////////////////////////////////////////////////////////////////
// Port / Part Pin Declarations
///////////////////////////////////////////////////////////////////////////////

    inout  SI ;
    inout  SO ;
    inout  DQ3;
    inout  DQ2;

    input  SCK  ;
    input  CSNeg;
    inout  DS   ;
    input  RESETNeg;
    output INTNeg;

    // interconnect path delay signals
    wire   SCK_ipd     ;
    wire   SI_ipd      ;
    wire   SO_ipd      ;
    wire   CSNeg_ipd   ;
    wire   RESETNeg_ipd;
 
    wire DQ3_ipd;
    wire DQ2_ipd;
    wire DQ1_ipd;
    wire DQ0_ipd;

    wire [3:0] Din;
    assign Din = {DQ3_ipd,
                   DQ2_ipd,
                   SO_ipd,
                   SI_ipd};

    wire [3:0] Dout;
    assign Dout = {DQ3,
                    DQ2,
                    SO,
                    SI};

    wire DQ3_in;
    assign DQ3_in = DQ3_ipd;
    wire DQ2_in;
    assign DQ2_in = DQ2_ipd;

    wire SI_in            ;
    assign SI_in = SI_ipd ;

    wire SI_out           ;
    assign SI_out = SI    ;

    wire SO_in            ;
    assign SO_in = SO_ipd ;

    wire SO_out           ;
    assign SO_out = SO    ;

    wire   RESETNeg_in              ;
    //Internal pull-up
    assign RESETNeg_in = (RESETNeg_ipd === 1'bx) ? 1'b1 : RESETNeg_ipd;

    wire   RESETNeg_out             ;
    assign RESETNeg_out = RESETNeg  ;

    // internal delays
    reg RST_in      ;
    reg RST_out     ;
    reg SWRST_in    ;
    reg SWRST_out   ;
    reg ERSSUSP_in  ;
    reg ERSSUSP_out ;
    reg PRGSUSP_in  ;
    reg PRGSUSP_out ;
    reg PPBERASE_in ;
    reg PPBERASE_out;
    reg PASSULCK_in ;
    reg PASSULCK_out;
    reg PASSACC_in  ;
    reg PASSACC_out ;
    reg DPD_in      ;
    reg DPD_entered ;
    reg DPD_out     ;
    reg DPD_POR_in  ;
    reg DPD_POR_out ;
    reg DPDExt_out_start ;
    reg ICRC_ent    ;
    reg [2:0] counter_clock = 3'b000;

    wire   DPDEX_in;       // DPD Exit event
    reg    DPDExt_out  = 0; // DPD Exit event confirmed
    reg    DPDExt      = 0; // DPD Exit event detected

    // event control registers
    reg PRGSUSP_out_event;
    reg ERSSUSP_out_event;

    reg rising_edge_preload_mem     = 1'b0;
		
    reg rising_edge_CSNeg_ipd  = 1'b0;
    reg falling_edge_CSNeg_ipd = 1'b0;
    reg rising_edge_SCK_ipd    = 1'b0;
    reg falling_edge_SCK_ipd   = 1'b0;
    reg rising_edge_RESETNeg   = 1'b0;
    reg falling_edge_RESETNeg  = 1'b0;
    reg falling_edge_RST       = 1'b0;
    reg rising_edge_RST_out    = 1'b0;
    reg rising_edge_SWRST_out  = 1'b0;
    reg rising_edge_reseted    = 1'b0;

    reg falling_edge_write     = 1'b0;

    reg rising_edge_PoweredUp  = 1'b0;
    reg rising_edge_PSTART     = 1'b0;
    reg rising_edge_PDONE      = 1'b0;
    reg rising_edge_ESTART     = 1'b0;
    reg rising_edge_EDONE      = 1'b0;
    reg rising_edge_SEERC_START= 1'b0;
    reg rising_edge_SEERC_DONE = 1'b0;
    reg rising_edge_WSTART     = 1'b0;
    reg rising_edge_WDONE      = 1'b0;
    reg rising_edge_CSDONE     = 1'b0;
    reg rising_edge_BCDONE     = 1'b0;
    reg rising_edge_EESSTART   = 1'b0;
    reg rising_edge_EESDONE    = 1'b0;
    reg rising_edge_CRCSTART   = 1'b0;
    reg rising_edge_CRCDONE    = 1'b0;
    reg rising_edge_START_T1_in= 1'b0;
    
    reg rising_edge_DPD_out    = 1'b0;
    reg rising_edge_DPD_POR_out = 1'b0;
    reg rising_edge_DPDEX_out   = 1'b0;
    reg rising_edge_DPDEX_out_start  = 1'b0; 
    
    reg falling_edge_RDYBSY       = 0;

    reg falling_edge_PASSULCK_in = 1'b0;
    reg falling_edge_PPBERASE_in = 1'b0;

    reg RST;
    
    reg read_transaction  = 1;

    reg SOut_zd            = 1'bZ;
    reg SIOut_zd           = 1'bZ;
    reg RESETNegOut_zd     = 1'bZ;
    reg [7:0] Dout_zd = 4'bzzzz;

    wire  DQ3_zd   ;
    wire  DQ2_zd   ;
    wire  DQ1_zd   ;
    wire  DQ0_zd   ;

    assign {DQ3_zd,
            DQ2_zd,
            DQ1_zd,
            DQ0_zd  } = Dout_zd;

    reg DS_zd      = 1'bz;
    reg INTNeg_zd  = 1'bz;

    // Pull-up recomended for INTNeg
    wire INTNeg_pull_up;
    assign INTNeg_pull_up = (INTNeg_zd === 1'bx) ? 1 : INTNeg_zd;

    parameter UserPreload       = 1;
    parameter mem_file_name     = "s28hs256m4.mem";//"s28hs256m4.mem";
    parameter otp_file_name     = "s28hs256m4OTP.mem";//"none";

    parameter TimingModel       = "S28HS256MXXBHX4X0";

    parameter  PartID           = "s28hs256m4";
    parameter  MaxData          = 255;
    //parameter  MemSize          = 28'h3FFFFFF;
    //parameter  SecSize256       = 20'h3FFFF;  //Avi  update
	parameter  SecSize256       = 12'hFFF;  //Avi  update
	parameter  SecSize4         = 12'hFFF;  //4KB
	parameter  SecSize32        = 15'h7FFF; //32KB
	parameter  SecSize64        = 16'hFFFF; //64KB
	parameter  SecNumUni        = 8191; // Keep as 4KB default
    parameter  SecNumUni4       = 8191; 
	parameter  SecNumUni32      = 1023;
	parameter  SecNumUni64      = 511;
    parameter  SecNumHyb        = 8191; // Keep as 4KB default
    parameter  PageNum256       = 20'h3FFFF;
    parameter  AddrRANGE        = 28'h1FFFFFF;
    parameter  HiAddrBit        = 24; //for 256
    parameter  OTPSize          = 1023;
    parameter  OTPLoAddr        = 12'h000;
    parameter  OTPHiAddr        = 12'h3FF;
    parameter  SFDPLoAddr       = 16'h0000;
    parameter  SFDPHiAddr       = 16'h0243;
    parameter  SFDPLength       = 16'h0243;
    parameter  IDLength         = 16;
    parameter  BYTE             = 8;
    
    // Parameter page program time, in sector
    reg param_sec_write_time = 0;
    
    
    // ECC data unit check
    reg [31:0] ECC_data = 32'h00000000;
    integer ECC_check = 0;
    integer DEBUG_ADDR = 0;
    integer ECC_ERR = 0;
    integer DEBUG_CHECK = 0;


    //varaibles to resolve architecture used
    reg [24*8-1:0] tmp_timing;//stores copy of TimingModel
    reg [7:0] tmp_char1; //Define General Market or Secure Device
    reg       non_industrial_temp;
    integer found = 1'b0;
    integer dummy_cnt  = 0;
    integer rd_crc = 0;
    
    wire DMYCNT_ODD;
    assign DMYCNT_ODD = dummy_cnt[0];

    // If speedsimulation is needed uncomment following line

       `define SPEEDSIM;

    // powerup
    reg PoweredUp;

    // Memory Array Configuration
    reg BottomBoot = 1'b1;  //Top is 4KB 
    reg TopBoot    = 1'b1;   // Bottom is also 4KB
    reg UniformSec = 1'b1;  // Only Uniform 4KB sectors

    // FSM control signals
    reg PDONE     ;
    reg PSTART    ;
    reg PGSUSP    ;
    reg PGRES     ;

    reg RES_TO_SUSP_TIME;

    reg CSDONE    ;
    reg CSSTART   ;

    reg WDONE     ;
    reg WSTART    ;

    reg EESDONE   ;
    reg EESSTART  ;

    reg EDONE     ;
    reg ESTART    ;
    reg ESUSP     ;
    reg ERES      ;

    reg SEERC_START ;
    reg SEERC_DONE  ;

    reg CRCSTART  ;
    reg CRCDONE   ;
    reg CRCSUSP   ;
    reg CRCRES    ;
    

    reg reseted   ;

    //Flag for Password unlock command
    reg PASS_UNLOCKED     = 1'b0;
    reg [63:0] PASS_TEMP  = 64'hFFFFFFFFFFFFFFFF;

    reg INITIAL_CONFIG    = 1'b0;
    reg CHECK_FREQ        = 1'b0;

    reg ZERO_DETECTED     = 1'b0;

    // Flag for Blank Check
    reg NOT_BLANK         = 1'b0;

    // Wrap Length
    integer WrapLength;

    integer CRC_Start_Addr_reg = 0;
    integer CRC_End_Addr_reg   = 0;
    reg [31:0] icrc_in = 32'h00000000;
    reg [31:0] icrc_out = 32'hFFFFFFFF;
    reg icrc_tmp;

    wire ICRC_DATA;
    assign ICRC_DATA = (~((DQ3_ipd === 1'bz) || (DQ3_ipd === 1'bx)) &&
                        ~((DQ2_ipd === 1'bz) || (DQ2_ipd === 1'bx)) &&
                        ~((SO_ipd === 1'bz)  || (SO_ipd === 1'bx))  &&
                        ~((SI_ipd === 1'bz)  || (SI_ipd === 1'bx)));

    // Programming buffer
    integer WByte[0:511];
    // SFDP array
    integer SFDP_array[SFDPLoAddr:SFDPHiAddr];
    // OTP Memory Array and related ICRC counter
    integer OTPMem[OTPLoAddr:OTPHiAddr];
	integer otp_mem_cnt = 0;
    // Flash Memory Array
    integer Mem[0:AddrRANGE];

    //-----------------------------------------
    //  Registers
    //-----------------------------------------
    reg [7:0] SR1_in   = 8'h00;

    //Nonvolatile Status Register 1
    reg [7:0] STR1N    = 8'h00;

    wire [2:0] LBPROT_NV;

    assign LBPROT_NV = STR1N[4:2];

    //Volatile Status Register 1
    reg [7:0] STR1V    = 8'h00;
	wire [15:0] STR1Vbbar = {STR1V[7:0],~STR1V[7:0]};

    wire       PRGERR;
    wire       ERSERR;
    wire [2:0] LBPROT;
    wire       WRPGEN;
    wire       RDYBSY;

    assign PRGERR = STR1V[6]  ;
    assign ERSERR = STR1V[5]  ;
    assign LBPROT = STR1V[4:2];
    assign WRPGEN = STR1V[1]  ;
    assign RDYBSY = STR1V[0]  ;

    //Volatile Status Register 2
    reg [7:0] STR2V    = 8'h00;

    wire DICRCS;
    wire DICRCA;
    wire SESTAT;
    wire ERASES;
    wire PROGMS;

    assign DICRCS = STR2V[4];
    assign DICRCA = STR2V[3];
    assign SESTAT = STR2V[2];
    assign ERASES = STR2V[1];
    assign PROGMS = STR2V[0];

    //Nonvolatile Configuration Register 1
    reg [7:0] CFR1_in   = 8'h00;

    reg [7:0] CFR1N    = 8'h00;

    wire   SP4KBS_NV;
    wire   TBPROT_NV;
    wire   PLPROT_O;
//     wire   BPNV_O;
    wire   TB4KBS_NV;

    assign SP4KBS_NV = CFR1N[6];
    assign TBPROT_NV = CFR1N[5];
    assign PLPROT_O  = CFR1N[4];
//     assign BPNV_O    = CFR1N[3];
    assign TB4KBS_NV = CFR1N[2];

    //Volatile Configuration Register 1
    reg [7:0] CFR1V    = 8'h00;

    wire   SP4KBS;
    wire   TBPROT;
    wire   PLPROT;
    wire   BPNV;
    wire   TB4KBS;
    wire   TLPROT;

    assign SP4KBS = CFR1V[6];
    assign TBPROT = CFR1V[5];
    assign PLPROT = CFR1V[4];
    assign BPNV   = CFR1V[3];
    assign TB4KBS = CFR1V[2];
    assign TLPROT = CFR1V[0];
    

    //Nonvolatile Configuration Register 2
    reg [7:0] CFR2N    = 8'h08;

    //Volatile Configuration Register 2
    reg [7:0] CFR2V    = 8'h08;

    //Nonvolatile Configuration Register 3
    reg [7:0] CFR3N    = 8'h20;

    //Volatile Configuration Register 3
    reg [7:0] CFR3V    = 8'h20;
    
    wire   UNHYSA;

    //assign UNHYSA = UniformSec;
	assign UNHYSA = UniformSec;  

    //Nonvolatile Configuration Register 4
    reg [7:0] CFR4N    = 8'h08;

    //Volatile Configuration Register 4
    reg [7:0] CFR4V    = 8'h08;
    
    assign DPDPOR = CFR4V[2];

    //Nonvolatile Configuration Register 5
    reg [7:0] CFR5N    =  8'h00;

    //Volatile Configuration Register 5
    reg [7:0] CFR5V    = 8'h00;

//     wire   DSOSDR;
//     wire   PDSSDR;
    wire   SDRDDR;
    wire   QPI_IT;

    assign DSONOF = CFR5V[7];  //Avi 
    assign SDRDDR = CFR5V[1];
    assign QPI_IT = CFR5V[0];

    // ASP Register
    reg[15:0] ASPO    = 16'hFFFF;
    reg[15:0] ASPO_in = 16'hFFFF;

    wire    ASPRDP;
    wire    ASPDYB;
    wire    ASPPPB;
    wire    ASPPWD;
    wire    ASPPER;
    wire    ASPPRM;
    assign  ASPRDP = ASPO[5];
    assign  ASPDYB = ASPO[4];
    assign  ASPPPB = ASPO[3];
    assign  ASPPWD = ASPO[2];
    assign  ASPPER = ASPO[1];
    assign  ASPPRM = ASPO[0];

    // Password register
    reg[63:0] PWDO    = 64'hFFFFFFFFFFFFFFFF;
    reg[63:0] PWDO_in = 64'hFFFFFFFFFFFFFFFF;

    // PPB Lock Register
    reg[7:0] PPLV     = 8'h01;
    reg[7:0] PPLV_in  = 8'h01;

    wire   PPBLCK;
    assign PPBLCK = PPLV[0];

    // PPB Access Register
    reg[7:0] PPAV             = 8'hFF;
    reg[7:0] PPAV_in          = 8'hFF;

    reg[SecNumHyb:0] PPB_bits  = {8192{1'b1}};

    // DYB Access Register
    reg[7:0] DYAV             = 8'hFF;
    reg[7:0] DYAV_in          = 8'hFF;
	reg[7:0] DYAV_inbar          = 8'hFF;

    reg[SecNumHyb:0] DYB_bits  = {8192{1'b1}};
    // AutoBoot Register
    reg[31:0] ATBN    = 32'h00000000;
    reg[31:0] ATBN_in = 32'h00000000;

    wire   ATBTEN;
    assign ATBTEN = ATBN[0];

    // Pointer Address Registers
    reg[15:0] EFX0O    = 16'h0000;
    reg[15:0] EFX0O_in = 16'h0000;
    reg[15:0] EFX1O    = 16'h0000;
    reg[15:0] EFX1O_in = 16'h0000;
    reg[15:0] EFX2O    = 16'h0000;
    reg[15:0] EFX2O_in = 16'h0000;
    reg[15:0] EFX3O    = 16'h0000;
    reg[15:0] EFX3O_in = 16'h0000;
    reg[15:0] EFX4O    = 16'h0000;
    reg[15:0] EFX4O_in = 16'h0000;
    // Address Trap Register
    reg[31:0] EATV     = 32'h00000000;
    reg[31:0] EATV_in  = 32'h00000000;
    // CRC Register
    reg[31:0] DCRV     = 32'h00000000;
    reg[31:0] DCRV_in  = 32'h00000000;
    // ICRC Registers
    reg[31:0] ICRV     = 32'hFFFFFFFF;
    reg[31:0] ICRV_in  = 32'hFFFFFFFF;
    reg[7:0]  ICEV     = 8'h01;
    reg[7:0]  ICEN     = 8'h01;

    wire   ITCRCE;
	wire [1:0] ICRCDL;
    assign ITCRCE = ~ICEV[0]; //invert because this signal is actually active LOW
	assign ICRCDL = ICEV[2:1];
	integer sgm_size;  

    // Sector Erase Count Register.
    reg [23:0] SECV = 23'h000000;
    reg [22:0] SECVAL_in [SecNumHyb:0];
	reg        SECCPT_in [SecNumHyb:0]; //Assume corruption does not happen in the model. So always static LOW

    // For multi-pass programming
    reg   MPASSREG [SecNumHyb:0];

    // Manufacturer and Device ID Register
    reg[8*(IDLength)-1:0] MDID_reg = 128'hFFFFFFFFFFFFFFFFFFFFA0020F195B34;
	//reg[16*(IDLength+1)-1:0] MDID_reg_DDbar = 256'h00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF5FA0FD02F00FE619A45Bcb34;

    // Unique ID Register
    reg[63:0] UID_reg  = 64'h0807060504030201;

    reg [7:0] WRAR_reg_in = 8'h00;
	reg [7:0] WRAR_reg_inbar = 8'hFF; 
	reg       WRAR_reg_in_correct = 0; 
    reg       DYAV_in_correct = 0;
    reg [7:0] RDAR_reg    = 8'h00;

    // ECC Register
    reg[7:0] ECSV      = 8'h00;
    // Error Detection Counter Register
    reg[15:0] ECTV     = 16'h0000;

    reg[SecNumHyb:0] ERS_nosucc  = {8192{1'b0}};

    // Interrupt Configuration register
    reg [7:0] INC0V = 8'hFF;
    reg [7:0] INC1V = 8'hFF;
    // Interrupt Status register
    reg [7:0] INS0V = 8'hFF;
    reg [7:0] INS1V = 8'hFF;
    // Interrupt Source register
    reg [7:0] INSRV = 8'hFF;

    //The Lock Protection Registers for OTP Memory space
    reg[7:0] LOCK_BYTE1;
    reg[7:0] LOCK_BYTE2;
    reg[7:0] LOCK_BYTE3;
    reg[7:0] LOCK_BYTE4;
    
    reg READ_PROTECT   = 0;
    reg [7:0] FIDR_reg = 16'hFF;

    reg write;
	reg write_new;
    reg cfg_write;
    reg read_out;
    reg dual          = 1'b0;
    reg rd_fast       = 1'b1;
    reg rd_slow       = 1'b0;
    reg ddr           = 1'b0;
    reg any_read      = 1'b0;

    reg DOUBLE        = 1'b0; //Double Data Rate (DDR) flag
    reg prog_erase    = 1'b0;
    
    reg DATA_STROBE   = 1'b0;

    reg change_TBPARM = 0;

    reg change_BP     = 0;
    reg[2:0] BP_bits  = 3'b0;

    reg     change_PageSize = 0;
    integer PageSize = 255;
	integer crc_pageBytes; 
    integer PageNum  = PageNum256;

    integer ASP_ProtSE = 0;
    integer Sec_ProtSE = 0;

    integer RESET_EN = 0; //Reset Enable Flag

    reg     change_addr;
    integer Address = 0;
	integer Address_erase = 0;
	integer Address_erase_ns = 0;  //for next_state evaluation
	integer Address_erase_cnt = 0; //for erase count transaction
    integer SectorSuspend = 0;
    integer SectorErased = 0;

    integer mem_data;

    reg [SecNumHyb : 0] corrupt_Sec;
    reg [7:0] OutputD;
    reg     bc_done ;

    reg oe   = 1'b0;
    reg oe_z = 1'b0;

    reg sSTART_T1 = 1'b0;
    reg START_T1_in = 1'b0;

    integer start_delay;
    reg start_autoboot;
    integer ABSD;

    integer Byte_number = 0;

    // Sector is protect if Sec_Prot(SecNum) = '1'
    reg [SecNumHyb:0] Sec_Prot  = 8192'b0;

    reg [8*(SFDPLength+1)-1:0] SFDP_array_tmp ;
    reg [7:0]                  SFDP_tmp;

    // timing check violation
    reg Viol = 1'b0;

    integer WOTPByte;
    integer AddrLo;
    integer AddrHi;

    reg[7:0]  old_bit, new_bit;
    integer old_int, new_int;
    reg[63:0] old_pass;
    reg[63:0] new_pass;
    reg[7:0]  old_pass_byte;
    reg[7:0]  new_pass_byte;
    integer wr_cnt;
    integer cnt;

    integer read_cnt  = 0;
    integer icrc_cnt  = 0;
    integer cnt_icrc32  = 0;
    integer read_addr = 0;
    integer byte_cnt  = 1;
    integer pgm_page = 0;
    integer SecAddr = 0;
	integer Bi = 0;   // For indexing Manufacturer ID to calculate CRC

    reg [7:0] data_out;
	reg [7:0] data_outb;
	reg [7:0] data_out_prev;
	reg [7:0] data_out_new;
	reg [3:0] data_out_nibble[0:3];
	
	integer wrreg_bytes = 0;
	integer pgpwd_bytes = 0;
	
    time SCK_cycle = 0;
    time prev_SCK;
    time tdevice_SEERC;
    reg  glitch = 1'b0;
    reg  glitch_ds = 1'b0;
    reg  DataDriveOut_SO = 1'bZ ;
    reg  DataDriveOut_SI = 1'bZ ;
    reg [5:0] DataDriveOut_Dout = 6'bZ ;
    reg DataDriveOut_DS  = 1'bZ ;
	reg DataDriveOut_DS_start = 1'b0;
	reg read_out_start = 1'b0;
	wire [4:0] addr_msb;
	
	assign  addr_msb  = 	CFR2V[7] ? 31 : 23; 

	reg [7:0] opcode_byte;
	reg block_erase_is_allowed = 0;
	reg half_block_erase_is_allowed = 0;

	integer as_cnt = 0; 	 //active state count
	integer as_dc_cnt = 0;   //active state dummy cycle cnt
	integer as_data_cnt = 0; //active state data cnt

///////////////////////////////////////////////////////////////////////////////
//Interconnect Path Delay Section
///////////////////////////////////////////////////////////////////////////////
    buf   (DQ3_ipd , DQ3 ); //buf g(out,in)
    buf   (DQ2_ipd , DQ2 );
    buf   (SCK_ipd, SCK);
    buf   (SI_ipd, SI);
    buf   (SO_ipd, SO);
    buf   (CSNeg_ipd, CSNeg);
    buf   (RESETNeg_ipd, RESETNeg);

///////////////////////////////////////////////////////////////////////////////
// Propagation  delay Section
///////////////////////////////////////////////////////////////////////////////  
    nmos   (DQ3 ,   DQ3_zd  , 1);  // out, in, ctrl , ctrl=1 out(0,1,x,z) = in (0,1,x,z)
    nmos   (DQ2 ,   DQ2_zd  , 1);
    nmos   (SO  ,   DQ1_zd  , 1);
    nmos   (SI  ,   DQ0_zd  , 1);
    nmos   (SI,       SIOut_zd       , 1);
    nmos   (SO,       SOut_zd        , 1);
    nmos   (DS, DS_zd, 1);
    nmos   (INTNeg  ,   INTNeg_pull_up   , 1);

    // Needed for TimingChecks
    // VHDL CheckEnable Equivalent

    //Single Data Rate Operations
    wire sdro;
    assign sdro = PoweredUp && ~DOUBLE;
    wire sdro_io1;
    assign sdro_io1 = PoweredUp && ~DOUBLE && ~dual;

    //Dual Data Rate Operations
    wire ddro;
    assign ddro = PoweredUp && ddr;

    wire ddro_io1;
    assign ddro_io1 = PoweredUp && DOUBLE && ~dual;

    wire rd ;
    wire fast_rd ;
    wire ddrd ;
    wire oddr ;
    wire osdr ;

    assign fast_rd = rd_fast;
    assign rd      = rd_slow;
    assign ddrd    = ddr;
    assign oddr    = SDRDDR & QPI_IT;
    assign osdr    = ~SDRDDR & QPI_IT;
    
    // IF F>50MHz F51M = 1
    reg freq51;
    wire F51M;
    assign F51M = freq51;

    wire prg_ers;
    assign prg_ers = prog_erase;

    wire datain;
    assign datain = ~QPI_IT & (SOut_zd === 1'bz);

    wire odatain;
    assign odatain = QPI_IT & ~SDRDDR & (SOut_zd === 1'bz);

    wire odatain_ddr;
	reg  check_ddr_timing;
    assign odatain_ddr = QPI_IT & check_ddr_timing & (SOut_zd === 1'bz) ;
    
	

	
     // SPI and F > 50MHz 4ns
    wire NegOPI_F51M;
    assign NegOPI_F51M  = ~QPI_IT && F51M ; 
    
    // SPI and F <= 50MHz 5ns
    wire NegOPI_NegF51M;
    assign NegOPI_NegF51M  = ~QPI_IT && ~F51M ;
    
    reg mode3;
    always @(CSNeg or SDRDDR or QPI_IT)
    begin
        if ((falling_edge_CSNeg_ipd || rising_edge_CSNeg_ipd) && !(SDRDDR & QPI_IT) && SCK)
            mode3 = 1'b1;
        else if ((falling_edge_CSNeg_ipd || rising_edge_CSNeg_ipd) && (!SCK || (SDRDDR & QPI_IT)))
            mode3 = 1'b0;
    end
    wire mode3sdr;
    wire mode3spi;
    assign mode3sdr = mode3 & QPI_IT;
    assign mode3spi = mode3 & ~QPI_IT;
    

    memory_features memory_features_i0();
specify
        // tipd delays: interconnect path delays , mapped to input port delays.
        // In Verilog is not necessary to declare any tipd_ delay variables,
        // they can be taken from SDF file
        // With all the other delays real delays would be taken from SDF file

    // tpd delays
    specparam        tpd_SCK_SO_spi              = 1;   // tV
    specparam        tpd_SCK_SO_sdr              = 1;   // tV
    specparam        tpd_CSNeg_SO            = 1;   // tDIS
    specparam        tpd_SCK_DS              = 1;   // tV DS
    specparam        tpd_CSNeg_DS            = 1;   //tDSV,tDSZ

    //tsetup values: setup times
    specparam        tsetup_CSNeg_SCK_NegF51 = 1;   // tCSS edge /
    specparam        tsetup_CSNeg_SCK_F51    = 1;   // tCSS edge /
    specparam        tsetup_CSNeg_SCK_osdr   = 1;   // tCSS edge /
    specparam        tsetup_CSNeg_SCK_oddr   = 1;   // tCSS edge /

    specparam        tsetup_SI_SCK_spiF51       = 1;   // tSU  edge /
    specparam        tsetup_SI_SCK_spiNegF51    = 1;   // tSU  edge /
    specparam        tsetup_SI_SCK_osdr      = 1;   // tSU  edge /
    specparam        tsetup_SI_SCK_oddr      = 1;   // tSU
    specparam        tsetup_RESETNeg_CSNeg   = 1;   // tRS  edge \

    //thold values: hold times
    specparam        thold_CSNeg_SCK_mode0   = 1;  //tCSH3 edge /
    specparam        thold_CSNeg_SCK_mode3sdr   = 1;  //tCSH3 edge /
    specparam        thold_CSNeg_SCK_mode3spi   = 1;  //tCSH3 edge /
    specparam        thold_CSNeg_SCK_sdr     = 1;   // tCSH edge /
    specparam        thold_CSNeg_SCK_ddr     = 1;   // tCSH edge /
    specparam        thold_SI_SCK_sdr        = 1;   // tHD  edge /
    specparam        thold_SI_SCK_ddr        = 1;   // tHD
    specparam        thold_SI_SCK_spiF51        = 1;   // tHD
    specparam        thold_SI_SCK_spiNegF51        = 1;   // tHD
    specparam        thold_SI_SCK_osdr       = 1;   // tHD  edge /
    specparam        thold_SI_SCK_oddr       = 1;   // tHD
    specparam        thold_CSNeg_RESETNeg    = 1;   // tRH  edge /

    // tpw values: pulse width
    specparam        tpw_SCK_normal_rd       = 1;
    specparam        tpw_SCK_fast_rd         = 1;
    specparam        tpw_SCK_ddr_rd          = 1;
    specparam        tpw_CSNeg_posedge       = 1;   // tCS
    specparam        tpw_CSNeg_wip_posedge   = 1;   // tCS
    specparam        tpw_CSNeg_prg_ers_posedge = 1; // tCS
    specparam        tpw_RESETNeg_negedge    = 1;   // tRP
    specparam        tpw_RESETNeg_posedge    = 1;   // tRS

    // tperiod min (calculated as 1/max freq)
    specparam        tperiod_SCK_normal_rd   = 1;   // 50 MHz
    specparam        tperiod_SCK_fast_rd     = 1;   //166 MHz
    specparam        tperiod_SCK_ddr_rd      = 1;   //100 MHz

    `ifdef SPEEDSIM
        // WRR Cycle Time
        specparam        tdevice_WRR               = 8e6;//tW = 8us
        // Page Program Operation 4KB/256B
        specparam        tdevice_PP_256            = 75e6; //tPP = 75us
        // Sector Erase Operation
        specparam        tdevice_SE4               = 200e6;//tSE = 200us
        // Sector Erase Count register max time
        specparam        tdevice_SEERC_max         = 60e6; //tSEC = 60 us
        // Sector Erase Count register typ time
        specparam        tdevice_SEERC_typ         = 55e6; //tSEC = 55 us
        // Sector Erase Count register mic time
        specparam        tdevice_SEERC_min         = 55e6; //tSEC = 55 us
		// Bulk Erase Operation
        specparam        tdevice_HBE               = 1e9;//tBE = 1ms
        // Bulk Erase Operation
        specparam        tdevice_BE                = 2e9;//tBE = 2ms
        // Bulk Erase Operation
        specparam        tdevice_CE                = 258e9;//tCE = 258ms
        // Evaluate Erase Status Time
        specparam        tdevice_EES               = 5.1e6; //tEES = 5.1us
        // Suspend Latency
        specparam        tdevice_SUSP              = 4e6;  //tSL = 4us
        // Resume to next Suspend Time
        specparam        tdevice_RS                = 10e6; //tRS = 10 us
        // RESET# Low to CS# Low
        specparam        tdevice_RPH               = 300e6; //tRPH = 300 us
        // internal device reset form soft reset
        specparam        tdevice_SR               = 3e6; //tRPH = 3 us
        // CS# High other transactions
        specparam        tdevice_CS                = 30e3; //tCS = 30 ns
        // CS# High Read
        specparam        tdevice_CSR               = 10e3; //tCS = 10 ns
        // VDD (min) to CS# Low
        specparam        tdevice_PU                = 3e6;//tPU = 3us
        // CRC setup time
        specparam        tdevice_CRCSETUP          = 17e6;//tCRCSETUP = 17us
        // CRC suspend latency
        specparam        tdevice_CRCSL             = 64e6;//tCRCSL = 64us
        // CRC Resume to next suspend
        specparam        tdevice_CRCRL             = 100e6;//tCRCRL = 100us
        // ICRC suspend time
        specparam        tdevice_PS                = 15e6;//tCRCRL = 15us
        // Password Unlock to Password Unlock Time
        specparam        tdevice_PASSACC           = 100e6;// 100us
        // CS# High to Power Down Mode - Time to Enter DPD mode
        specparam        tdevice_ENTDPD            = 3e6;     // 3 us
        // Time to Exit DPD mode
        specparam        tdevice_EXTDPD            = 20e6;   // 20 us
        // CS# pulse width to exit DPD mode
        specparam        tdevice_CSDPD             = 20e3;    // 0.02us - minimum
        // Blank Check (4KB Sector) time 1 ms (typical, max is 2 ms)
        specparam        tdevice_BC                = 2e9;
    `else
        // WRR Cycle Time
        specparam        tdevice_WRR               = 8e9; //tW = 8ms
        // Page Program Operation 4KB/256B
        specparam        tdevice_PP_256            = 750e6; //tPP = 750us
        // Sector Erase Operation
        specparam        tdevice_SE4               = 200e9; //tSE = 200ms
        // Sector Erase Count register max time
        specparam        tdevice_SEERC_max         = 60e6; //tSEC = 60 us
        // Sector Erase Count register typ time
        specparam        tdevice_SEERC_typ         = 55e6; //tSEC = 55 us
        // Sector Erase Count register mic time
        specparam        tdevice_SEERC_min         = 55e6; //tSEC = 55 us
        // Bulk Erase Operation
        specparam        tdevice_HBE               = 1e12;//tBE = 1s
        // Bulk Erase Operation
        specparam        tdevice_BE                = 2e12;//tBE = 2s
        // Bulk Erase Operation
        specparam        tdevice_CE                = 258e12;//tCE = 258s
        // Evaluate Erase Status Time
        specparam        tdevice_EES               = 51e6;//tEES = 51us
        // Suspend Latency
        specparam        tdevice_SUSP              = 40e6; //tSL = 40us
        // Resume to next Suspend Time
        specparam        tdevice_RS                = 100e6;//tRS = 100 us
        // RESET# Low to CS# Low
        specparam        tdevice_RPH               = 300e6; //tRPH = 300 us
        // internal device reset form soft reset
        specparam        tdevice_SR                = 30e6; //tSR = 30 us
         // CS# High other transactions
        specparam        tdevice_CS                = 30e3; //tCS = 30 ns
        // CS# High Read
        specparam        tdevice_CSR               = 10e3; //tCS = 10 ns
        // VDD (min) to CS# Low
        specparam        tdevice_PU                = 300e6;//tPU = 300us
        // CRC setup time
        specparam        tdevice_CRCSETUP          = 17e6;//tCRCSETUP = 17us
        // CRC suspend latency
        specparam        tdevice_CRCSL             = 64e6;//tCRCSL = 64us
        // CRC Resume to next suspend
        specparam        tdevice_CRCRL             = 100e6;//tCRCRL = 100us
        // ICRC suspend time
        specparam        tdevice_PS                = 15e6;//tCRCRL = 15us
        // Password Unlock to Password Unlock Time
        specparam        tdevice_PASSACC           = 100e6;// 100us
        // CS# High to Power Down Mode
        specparam        tdevice_ENTDPD            = 3e6;     // 3 us
        // Time to Exit DPD mode
        specparam        tdevice_EXTDPD            = 20e6;    // 20 us
        // CS# pulse width to exit DPD mode
        specparam        tdevice_CSDPD             = 20e3;    // 0.02us - minimum
        // Blank Check (4KB Sector) time 1 ms (typical, max is 2 ms)
        specparam        tdevice_BC                = 2e9;
    `endif // SPEEDSIM

///////////////////////////////////////////////////////////////////////////////
// Input Port  Delays  don't require Verilog description
///////////////////////////////////////////////////////////////////////////////
// Path delays                                                               //
///////////////////////////////////////////////////////////////////////////////
    if (~QPI_IT && ~glitch )     (SCK => SO)  = tpd_SCK_SO_spi;
    if (~QPI_IT && ~glitch )     (SCK => SI)  = tpd_SCK_SO_spi;
    if (~QPI_IT && ~glitch )     (SCK => DQ2) = tpd_SCK_SO_spi;
    if (~QPI_IT && ~glitch )     (SCK => DQ3) = tpd_SCK_SO_spi;

    
    if (QPI_IT && ~glitch )     (SCK => SO)  = tpd_SCK_SO_sdr;
    if (QPI_IT && ~glitch )     (SCK => SI)  = tpd_SCK_SO_sdr;
    if (QPI_IT && ~glitch )     (SCK => DQ2) = tpd_SCK_SO_sdr;
    if (QPI_IT && ~glitch )     (SCK => DQ3) = tpd_SCK_SO_sdr;


    if (~glitch)   (CSNeg => SI)  = tpd_CSNeg_SO;
    if (~glitch)   (CSNeg => SO)  = tpd_CSNeg_SO;
    if (~glitch)   (CSNeg => DQ2) = tpd_CSNeg_SO;
    if (~glitch)   (CSNeg => DQ3) = tpd_CSNeg_SO;
    
    if (QPI_IT && ~glitch )     (SCK => DS)  = tpd_SCK_DS;

    (CSNeg => DS) = tpd_CSNeg_DS;

///////////////////////////////////////////////////////////////////////////////
// Timing Violation                                                          //
///////////////////////////////////////////////////////////////////////////////
    $setup ( CSNeg   &&& NegOPI_NegF51M , posedge SCK ,  tsetup_CSNeg_SCK_NegF51);
    $setup ( CSNeg   &&& NegOPI_F51M     , posedge SCK ,  tsetup_CSNeg_SCK_F51);
    $setup ( CSNeg   &&& osdr        , posedge SCK ,  tsetup_CSNeg_SCK_osdr);
    $setup ( CSNeg   &&& oddr        ,         SCK ,  tsetup_CSNeg_SCK_oddr);

    $setup ( SI     &&& NegOPI_F51M      , posedge SCK   ,  tsetup_SI_SCK_spiF51);
    $setup ( SI     &&& NegOPI_NegF51M   , posedge SCK   ,  tsetup_SI_SCK_spiNegF51);
    $setup ( SI     &&& odatain         , posedge SCK   ,  tsetup_SI_SCK_osdr);
    $setup ( SI     &&& odatain_ddr     ,         SCK   ,  tsetup_SI_SCK_oddr);

    $setup ( RESETNeg, CSNeg                  ,  tsetup_RESETNeg_CSNeg  , Viol);//
    
    $hold (negedge SCK, CSNeg &&& ~mode3, thold_CSNeg_SCK_mode0);
    $hold (posedge SCK, posedge CSNeg &&& mode3sdr, thold_CSNeg_SCK_mode3sdr);
    $hold (posedge SCK, posedge CSNeg &&& mode3spi, thold_CSNeg_SCK_mode3spi);


//     $hold  ( posedge SCK , CSNeg &&& ~ddrd    ,  thold_CSNeg_SCK_sdr);
//     $hold  ( posedge SCK , CSNeg &&& ddrd     ,  thold_CSNeg_SCK_ddr);


    $hold ( posedge SCK, SI  &&& NegOPI_F51M    ,   thold_SI_SCK_spiF51);
    $hold ( posedge SCK, SI  &&& NegOPI_NegF51M ,   thold_SI_SCK_spiNegF51);
    $hold  ( posedge SCK, SI &&& odatain        ,    thold_SI_SCK_osdr);
    $hold  (         SCK, SI &&& odatain_ddr    ,    thold_SI_SCK_oddr);

    $hold  ( posedge RESETNeg, negedge CSNeg  ,  thold_CSNeg_RESETNeg   , Viol);//

    $width ( posedge SCK &&& rd          , tpw_SCK_normal_rd);
    $width ( negedge SCK &&& rd          , tpw_SCK_normal_rd);
    $width ( posedge SCK &&& fast_rd     , tpw_SCK_fast_rd);
    $width ( negedge SCK &&& fast_rd     , tpw_SCK_fast_rd);
    $width ( posedge SCK &&& ddrd        , tpw_SCK_ddr_rd);
    $width ( negedge SCK &&& ddrd        , tpw_SCK_ddr_rd);

    $width ( posedge CSNeg &&& any_read  , tpw_CSNeg_posedge);
    $width ( posedge CSNeg &&& prg_ers   , tpw_CSNeg_prg_ers_posedge);
    $width ( posedge CSNeg &&& RDYBSY       , tpw_CSNeg_wip_posedge);
    $width ( negedge RESETNeg            , tpw_RESETNeg_negedge);
    $width ( posedge RESETNeg            , tpw_RESETNeg_posedge);

    $period ( posedge SCK &&& rd         , tperiod_SCK_normal_rd);
    $period ( posedge SCK &&& fast_rd    , tperiod_SCK_fast_rd);
    $period ( posedge SCK &&& ddrd       , tperiod_SCK_ddr_rd);


endspecify

///////////////////////////////////////////////////////////////////////////////
// Main Behavior Block                                                       //
///////////////////////////////////////////////////////////////////////////////
// FSM states
 parameter IDLE             = 6'd0;
 parameter RESET_STATE      = 6'd1;
 parameter PGERS_ERROR      = 6'd2;
 parameter WRITE_ALL_REG    = 6'd3;
 parameter WRITE_ANY_REG    = 6'd5;
 parameter PAGE_PG          = 6'd6;
 parameter OTP_PG           = 6'd7;
 parameter PG_SUSP          = 6'd8;
 parameter SECTOR_ERS       = 6'd9;
 parameter BULK_ERS         = 6'd10;
 parameter ERS_SUSP         = 6'd11;
 parameter ERS_SUSP_PG      = 6'd12;
 parameter ERS_SUSP_PG_SUSP = 6'd13;
 parameter CRC_Calc         = 6'd14;
 parameter CRC_SUSP         = 6'd15;
 parameter DP_DOWN          = 6'd16;
 parameter PASS_PG          = 6'd17;
 parameter PASS_UNLOCK      = 6'd18;
 parameter PPB_PG           = 6'd19;
 parameter PPB_ERS          = 6'd20;
 parameter ASP_PG           = 6'd22;
 parameter PLB_PG           = 6'd23;
 parameter DYB_PG           = 6'd25;
//  parameter NVDLR_PG         = 6'd26;
 parameter BLANK_CHECK      = 6'd27;
 parameter EVAL_ERS_STAT    = 6'd28;
 parameter SEERC            = 6'd29;
 parameter AUTOBOOT         = 6'd30;
 parameter HALF_BLK_ERS     = 6'd31;
 parameter BLK_ERS          = 6'd32;
 
 
    typedef enum reg [6:0] {
			 IDLE_ ,
			 RESET_STATE_ ,
			 PGERS_ERROR_ ,
			 WRITE_ALL_REG_ ,
			 WRITE_ANY_REG_ ,
			 PAGE_PG_ ,
			 OTP_PG_ ,
			 PG_SUSP_ ,
			 SECTOR_ERS_ ,
			 BULK_ERS_ ,
			 ERS_SUSP_ ,
			 ERS_SUSP_PG_ ,
			 ERS_SUSP_PG_SUSP_ ,
			 CRC_Calc_ ,
			 CRC_SUSP_ ,
			 DP_DOWN_ ,
			 PASS_PG_ ,
			 PASS_UNLOCK_ ,
			 PPB_PG_ ,
			 PPB_ERS_ ,
			 ASP_PG_ ,
			 PLB_PG_ ,
			 DYB_PG_ ,
			//  NVDLR_PG_ ,
			 BLANK_CHECK_ ,
			 EVAL_ERS_STAT_ ,
			 SEERC_ ,
			 AUTOBOOT_ 
                        } fsm_states;
 

 reg [5:0] current_state;
 reg [5:0] next_state;


// Instruction type
 parameter NONE            = 7'd1;
 parameter WRENB_0_0       = 7'd2;
 parameter WRDIS_0_0       = 7'd3;
 parameter WRARG_C_1       = 7'd5;
 parameter CLPEF_0_0       = 7'd6;
 parameter RDARG_C_0       = 7'd8;
 parameter RDSR1_0_0       = 7'd9;  
 // parameter RDSR1_4_0       = 7'd10; 
 parameter RDSR2_0_0       = 7'd11; 
 // parameter RDSR2_4_0       = 7'd12; 
 parameter RDIDN_0_0       = 7'd13; 
 // parameter RDIDN_4_0       = 7'd14; 
 parameter RSFDP_C_0       = 7'd16; 
 parameter RDUID_0_0       = 7'd17; 
 // parameter RDUID_4_0       = 7'd18; 
 parameter RDECC_4_0       = 7'd19;
 parameter RDECC_C_0       = 7'd20;
 parameter RDAY1_C_0       = 7'd21;
 parameter RDAY1_4_0       = 7'd22;
 parameter RDAY2_4_0       = 7'd23;
 parameter RDAY2_C_0       = 7'd24;
 parameter PRPGE_4_1       = 7'd25;
 parameter PRPGE_C_1       = 7'd26;
 parameter ERCHP_0_0_60    = 7'd27;
 parameter ERCHP_0_0_C7    = 7'd28;
 parameter ERO04_4_0       = 7'd29;
 parameter ERO04_C_0       = 7'd30;
 parameter ERO32_4_0       = 7'd31;
 parameter ERO32_C_0       = 7'd32;
 parameter ERO64_4_0       = 7'd33;
 parameter ERO64_C_0       = 7'd34;
 parameter EVERS_C_0       = 7'd35;
 parameter SPEPD_0_0       = 7'd36;
 parameter RSEPD_0_0       = 7'd37;
 parameter PRSSR_C_1       = 7'd38;
 parameter RDSSR_C_0       = 7'd39;
 parameter RDDYB_4_0       = 7'd40;
 parameter RDDYB_C_0       = 7'd41;
 parameter WRDYB_4_1       = 7'd42;
 parameter WRDYB_C_1       = 7'd43;
 parameter RDPPB_4_0       = 7'd44;
 parameter RDPPB_C_0       = 7'd45;
 parameter PRPPB_4_0       = 7'd46;
 parameter PRPPB_C_0       = 7'd47;
 parameter ERPPB_0_0       = 7'd48;
 parameter RDPLB_0_0       = 7'd49;
 parameter WRPLB_0_0       = 7'd50;
 parameter SRSTE_0_0       = 7'd51;
 parameter SFRST_0_0       = 7'd52;
 parameter CLECC_0_0       = 7'd53;
 parameter DICHK_C_1       = 7'd54;
 parameter PWDUL_0_1       = 7'd55;
 parameter ENDPD_0_0       = 7'd56;
 parameter SEERC_C_0       = 7'd57;
 parameter EN4BA_0_0       = 7'd58;
 parameter EX4BA_0_0       = 7'd59;
 parameter EUDPD_0_0       = 7'd60;
 parameter PGPWD_0_1       = 7'd61;
 parameter RDOC3_4_0       = 7'd62;
 parameter RDOC3_C_0       = 7'd63;
 parameter RDOC4_4_0       = 7'd64;
 parameter WRENV_0_0       = 7'd65;
 parameter WRREG_0_1       = 7'd66;
 parameter PRPG1_4_1       = 7'd67;
 parameter PRPG1_C_1       = 7'd68;
 parameter PRPG2_4_1       = 7'd69;
 parameter RDOC1_4_0       = 7'd70;
 parameter RDOC1_C_0       = 7'd71;
 parameter RDOC5_C_0       = 7'd72;
 parameter RDOC6_4_0       = 7'd73;
 parameter RDOC5_4_0       = 7'd74;
 parameter PRPG2_C_1       = 7'd75;
 parameter ER256_4_0       = 7'd76;
 parameter RDCRC_4_0       = 7'd77;
 parameter RDQID_0_0       = 7'd78;
 parameter RDAY7_C_0       = 7'd79;
 parameter RDAY7_4_0       = 7'd80;
 parameter RDAY5_C_0	   = 7'd81;
 parameter RDAY5_4_0	   = 7'd82;
 parameter PRPG3_C_1	   = 7'd83;
 parameter PRPG3_4_1	   = 7'd84;
 parameter RDAY4_C_0	   = 7'd85;
 parameter RDAY4_4_0	   = 7'd86;
parameter PRASP_0_1        = 7'd87;

 
   typedef enum reg [6:0] {
              NONE_            ,
              WRENB_0_0_       ,
              WRDIS_0_0_       ,
              WRARG_C_1_       ,
              CLPEF_0_0_       ,
              RDARG_C_0_       ,
              RDSR1_0_0_       ,  
                   RDSR1_4_0_       ,    //Unused
              RDSR2_0_0_       , 
                  RDSR2_4_0_       ,     //Unused
              RDIDN_0_0_       , 
			  RDQID_0_0_       ,
                  RDIDN_4_0_       ,     //Unused
              RSFDP_C_0_       , 
              RDUID_0_0_       , 
                  RDUID_4_0_       ,      //Unused
              RDECC_4_0_       ,
              RDECC_C_0_       ,
              RDAY1_C_0_       ,
              RDAY1_4_0_       ,
              RDAY2_4_0_       ,
              RDAY2_C_0_       ,
              PRPGE_4_1_       ,
              PRPGE_C_1_       ,
              ERCHP_0_0_60_    ,
			  ERCHP_0_0_C7_    ,
              ERO04_4_0_       ,
              ERO04_C_0_       , 
              ERO32_4_0_       ,
              ERO32_C_0_       ,
              ERO64_4_0_       ,
              ERO64_C_0_       ,
              EVERS_C_0_       ,
              SPEPD_0_0_       ,
              RSEPD_0_0_       ,
              PRSSR_C_1_       ,
              RDSSR_C_0_       ,
              RDDYB_4_0_       ,
              RDDYB_C_0_       ,
              WRDYB_4_1_       ,
              WRDYB_C_1_       ,
              RDPPB_4_0_       ,
              RDPPB_C_0_       ,
              PRPPB_4_0_       ,
              PRPPB_C_0_       ,
              ERPPB_0_0_       ,
              RDPLB_0_0_       ,
              WRPLB_0_0_       ,
              SRSTE_0_0_       ,
              SFRST_0_0_       ,
              CLECC_0_0_       ,
              DICHK_C_1_       ,
              PWDUL_0_1_       ,
              ENDPD_0_0_       ,
              SEERC_C_0_       ,
              EN4BA_0_0_       ,
              EX4BA_0_0_       ,
              EUDPD_0_0_       ,
              PGPWD_0_1_       ,
			  PRASP_0_1_       ,
              RDOC3_4_0_       ,
              RDOC3_C_0_       ,
              RDOC4_4_0_       ,
              WRENV_0_0_       ,
              WRREG_0_1_       ,
              PRPG1_4_1_       ,
              PRPG1_C_1_       ,
              PRPG2_4_1_       ,
              RDOC1_4_0_       ,
              RDOC1_C_0_       ,
              RDOC5_C_0_       ,
              RDOC6_4_0_       ,
			  RDOC5_4_0_       ,
              PRPG2_C_1_       ,
              ER256_4_0_       ,
              RDCRC_4_0_       ,
			  RDAY4_C_0_       ,
              RDAY4_4_0_       ,
              RDAY5_4_0_       ,
              RDAY5_C_0_       ,
			  RDAY7_C_0_	   ,
			  RDAY7_4_0_
						   } instructs_names;
 

// Command Register
 reg [6:0] Instruct;

//Bus cycle state
 parameter STAND_BY           = 4'd0;
 parameter OPCODE_BYTE        = 4'd1;
 parameter ADDRESS_BYTES      = 4'd2;
 parameter DUMMY_BYTES        = 4'd3;
 parameter MODE_BYTE          = 4'd4;
 parameter DATA_IN_BYTES      = 4'd5;
 parameter DATA_OUT_BYTES     = 4'd6;
 parameter CRC_OPCODE_BYTES   = 4'd7;
 parameter CRC_ADDRESS_BYTES  = 4'd8;
 parameter CRC_DATA_IN_BYTES  = 4'd9;
 parameter CRC_DATA_OUT_BYTES = 4'd10;

 reg [3:0] bus_cycle_state;
 
 event     Mev1, Mev2, Mev3, Mev4, Mev5, Mev6, Mev7, Mev8, Mev9, Meva, Mevb, Mevc, Mevd, Meve, Mevf,Mevg, Mevh, Mevi, Mevj, Mevk, Mevl ;
 
    typedef enum reg [3:0] {
						   SB_,
						   OP_,
						   AD_,
						   DM_,
						   MD_,
						   DI_,
						   DO_, 
                           CR_,
						   CA_,
						   CI_,
						   CO_
						   } spi_bus_cycle_states;


   instructs_names instruct_spi_enum;
   spi_bus_cycle_states bus_cycle_state_spi_enum;
   fsm_states current_state_spi_enum;
   
     always @(bus_cycle_state)
     begin
        case(bus_cycle_state)
	      STAND_BY           : bus_cycle_state_spi_enum = SB_;
          OPCODE_BYTE        : bus_cycle_state_spi_enum = OP_;
          ADDRESS_BYTES      : bus_cycle_state_spi_enum = AD_;
          DUMMY_BYTES        : bus_cycle_state_spi_enum = DM_;
          MODE_BYTE    	     : bus_cycle_state_spi_enum = MD_;
          DATA_IN_BYTES      : bus_cycle_state_spi_enum = DI_;
		  DATA_OUT_BYTES     : bus_cycle_state_spi_enum = DO_;
		  CRC_OPCODE_BYTES   : bus_cycle_state_spi_enum = CR_;
		  CRC_ADDRESS_BYTES  : bus_cycle_state_spi_enum = CA_;
		  CRC_DATA_IN_BYTES  : bus_cycle_state_spi_enum = CI_;
		  CRC_DATA_OUT_BYTES : bus_cycle_state_spi_enum = CO_;
        endcase
     end
   
     always @(Instruct)
     begin
        case(Instruct)	
		      NONE            : instruct_spi_enum = NONE_ ;
              WRENB_0_0       : instruct_spi_enum = WRENB_0_0_ ;
              WRDIS_0_0       : instruct_spi_enum = WRDIS_0_0_ ;
              WRARG_C_1       : instruct_spi_enum = WRARG_C_1_ ;
              CLPEF_0_0       : instruct_spi_enum = CLPEF_0_0_ ;
              RDARG_C_0       : instruct_spi_enum = RDARG_C_0_ ;
              RDSR1_0_0       : instruct_spi_enum = RDSR1_0_0_ ;  
              //     RDSR1_4_0       : instruct_spi_enum = RDSR1_4_0_ ;    //Unused
              RDSR2_0_0       : instruct_spi_enum = RDSR2_0_0_ ; 
               //   RDSR2_4_0       : instruct_spi_enum = RDSR2_4_0_ ;     //Unused
              RDIDN_0_0       : instruct_spi_enum = RDIDN_0_0_ ; 
              //    RDIDN_4_0       : instruct_spi_enum = RDIDN_4_0_ ;     //Unused
              RSFDP_C_0       : instruct_spi_enum = RSFDP_C_0_ ; 
              RDUID_0_0       : instruct_spi_enum = RDUID_0_0_ ; 
              //    RDUID_4_0       : instruct_spi_enum = RDUID_4_0_ ;      //Unused
              RDECC_4_0       : instruct_spi_enum = RDECC_4_0_ ;
              RDECC_C_0       : instruct_spi_enum = RDECC_C_0_ ;
              RDAY1_C_0       : instruct_spi_enum = RDAY1_C_0_ ;
              RDAY1_4_0       : instruct_spi_enum = RDAY1_4_0_ ;
              RDAY2_4_0       : instruct_spi_enum = RDAY2_4_0_ ;
              RDAY2_C_0       : instruct_spi_enum = RDAY2_C_0_ ;
              PRPGE_4_1       : instruct_spi_enum = PRPGE_4_1_ ;
              PRPGE_C_1       : instruct_spi_enum = PRPGE_C_1_ ;
              ERCHP_0_0_60    : instruct_spi_enum = ERCHP_0_0_60_ ;
			  ERCHP_0_0_C7    : instruct_spi_enum = ERCHP_0_0_C7_ ;
              ERO04_4_0       : instruct_spi_enum = ERO04_4_0_ ;
              ERO04_C_0       : instruct_spi_enum = ERO04_C_0_ ; 
              ERO32_4_0       : instruct_spi_enum = ERO32_4_0_ ;
              ERO32_C_0       : instruct_spi_enum = ERO32_C_0_ ;
              ERO64_4_0       : instruct_spi_enum = ERO64_4_0_ ;
              ERO64_C_0       : instruct_spi_enum = ERO64_C_0_ ;
              EVERS_C_0       : instruct_spi_enum = EVERS_C_0_ ;
              SPEPD_0_0       : instruct_spi_enum = SPEPD_0_0_ ;
              RSEPD_0_0       : instruct_spi_enum = RSEPD_0_0_ ;
              PRSSR_C_1       : instruct_spi_enum = PRSSR_C_1_ ;
              RDSSR_C_0       : instruct_spi_enum = RDSSR_C_0_ ;
              RDDYB_4_0       : instruct_spi_enum = RDDYB_4_0_ ;
              RDDYB_C_0       : instruct_spi_enum = RDDYB_C_0_ ;
              WRDYB_4_1       : instruct_spi_enum = WRDYB_4_1_ ;
              WRDYB_C_1       : instruct_spi_enum = WRDYB_C_1_ ;
              RDPPB_4_0       : instruct_spi_enum = RDPPB_4_0_ ;
              RDPPB_C_0       : instruct_spi_enum = RDPPB_C_0_ ;
              PRPPB_4_0       : instruct_spi_enum = PRPPB_4_0_ ;
              PRPPB_C_0       : instruct_spi_enum = PRPPB_C_0_ ;
              ERPPB_0_0       : instruct_spi_enum = ERPPB_0_0_ ;
              RDPLB_0_0       : instruct_spi_enum = RDPLB_0_0_ ;
              WRPLB_0_0       : instruct_spi_enum = WRPLB_0_0_ ;
              SRSTE_0_0       : instruct_spi_enum = SRSTE_0_0_ ;
              SFRST_0_0       : instruct_spi_enum = SFRST_0_0_ ;
              CLECC_0_0       : instruct_spi_enum = CLECC_0_0_ ;
              DICHK_C_1       : instruct_spi_enum = DICHK_C_1_ ;
              PWDUL_0_1       : instruct_spi_enum = PWDUL_0_1_ ;
              ENDPD_0_0       : instruct_spi_enum = ENDPD_0_0_ ;
              SEERC_C_0       : instruct_spi_enum = SEERC_C_0_ ;
              EN4BA_0_0       : instruct_spi_enum = EN4BA_0_0_ ;
              EX4BA_0_0       : instruct_spi_enum = EX4BA_0_0_ ;
              EUDPD_0_0       : instruct_spi_enum = EUDPD_0_0_ ;
              PGPWD_0_1       : instruct_spi_enum = PGPWD_0_1_ ;
              PRASP_0_1       : instruct_spi_enum = PRASP_0_1_ ;
              RDOC3_4_0       : instruct_spi_enum = RDOC3_4_0_ ;
              RDOC3_C_0       : instruct_spi_enum = RDOC3_C_0_ ;
              RDOC4_4_0       : instruct_spi_enum = RDOC4_4_0_ ;
              WRENV_0_0       : instruct_spi_enum = WRENV_0_0_ ;
              WRREG_0_1       : instruct_spi_enum = WRREG_0_1_ ;
              PRPG1_4_1       : instruct_spi_enum = PRPG1_4_1_ ;
              PRPG1_C_1       : instruct_spi_enum = PRPG1_C_1_ ;
              PRPG2_4_1       : instruct_spi_enum = PRPG2_4_1_ ;
              RDOC1_4_0       : instruct_spi_enum = RDOC1_4_0_ ;
              RDOC1_C_0       : instruct_spi_enum = RDOC1_C_0_ ;
              RDOC5_C_0       : instruct_spi_enum = RDOC5_C_0_ ;
              RDOC6_4_0       : instruct_spi_enum = RDOC6_4_0_ ;
			  RDOC5_4_0       : instruct_spi_enum = RDOC5_4_0_ ;
              PRPG2_C_1       : instruct_spi_enum = PRPG2_C_1_ ;
              ER256_4_0       : instruct_spi_enum = ER256_4_0_ ;
              RDCRC_4_0       : instruct_spi_enum = RDCRC_4_0_ ;
			  RDQID_0_0		  : instruct_spi_enum = RDQID_0_0_ ;
			  RDAY4_C_0       : instruct_spi_enum = RDAY4_C_0_ ;
              RDAY4_4_0       : instruct_spi_enum = RDAY4_4_0_ ;
              RDAY5_4_0       : instruct_spi_enum = RDAY5_4_0_ ;
              RDAY5_C_0       : instruct_spi_enum = RDAY5_C_0_ ;
			  RDAY7_C_0	      : instruct_spi_enum = RDAY7_C_0_ ;
			  RDAY7_4_0       : instruct_spi_enum = RDAY7_4_0_ ;
        endcase
     end
	 

	
	 
	 always @(current_state)
     begin
        case(current_state)
	      IDLE          : current_state_spi_enum = IDLE_          ;
          RESET_STATE   : current_state_spi_enum = RESET_STATE_   ;
          PGERS_ERROR   : current_state_spi_enum = PGERS_ERROR_   ;
		  WRITE_ALL_REG : current_state_spi_enum = WRITE_ALL_REG_ ;
          WRITE_ANY_REG : current_state_spi_enum = WRITE_ANY_REG_ ;
          PAGE_PG       : current_state_spi_enum = PAGE_PG_       ;
          OTP_PG        : current_state_spi_enum = OTP_PG_        ;
		  PG_SUSP       : current_state_spi_enum = PG_SUSP_    ;
          SECTOR_ERS    : current_state_spi_enum = SECTOR_ERS_    ;
		  BULK_ERS      : current_state_spi_enum = BULK_ERS_    ; 
          ERS_SUSP      : current_state_spi_enum = ERS_SUSP_      ;
          ERS_SUSP_PG   : current_state_spi_enum = ERS_SUSP_PG_   ;
		  ERS_SUSP_PG_SUSP : current_state_spi_enum = ERS_SUSP_PG_SUSP_ ;
		  CRC_Calc      : current_state_spi_enum = CRC_Calc_   ;
		  CRC_SUSP      : current_state_spi_enum = CRC_SUSP_   ;
		  DP_DOWN       : current_state_spi_enum = DP_DOWN_   ;
		  PASS_PG       : current_state_spi_enum = PASS_PG_   ;
		  PASS_UNLOCK   : current_state_spi_enum = PASS_UNLOCK_   ;
		  PPB_PG        : current_state_spi_enum = PPB_PG_   ;
		  PPB_ERS       : current_state_spi_enum = PPB_ERS_   ;
		  ASP_PG        : current_state_spi_enum = ASP_PG_   ;
		  PLB_PG        : current_state_spi_enum = PLB_PG_   ;
		  DYB_PG        : current_state_spi_enum = DYB_PG_   ;
		//  NVDLR_PG_ ,
		  BLANK_CHECK   : current_state_spi_enum = BLANK_CHECK_   ;
		  EVAL_ERS_STAT : current_state_spi_enum = EVAL_ERS_STAT_ ;
		  SEERC         : current_state_spi_enum = SEERC_ ;
		  AUTOBOOT      : current_state_spi_enum = AUTOBOOT_ ;
        endcase
     end
	

	always @(bus_cycle_state)
	begin
	 if((bus_cycle_state == ADDRESS_BYTES) || 
	    (bus_cycle_state == DATA_IN_BYTES) ||
		(bus_cycle_state == DATA_OUT_BYTES) ||
		(bus_cycle_state == CRC_OPCODE_BYTES) ||
		(bus_cycle_state == CRC_ADDRESS_BYTES) ||
		(bus_cycle_state == CRC_DATA_IN_BYTES) ||
		(bus_cycle_state == CRC_DATA_OUT_BYTES))
		check_ddr_timing = SDRDDR; 
	else
	    check_ddr_timing = 1'b0;
	end	
   
// CS# Signaling Reset states
 parameter SIGRES_IDLE          = 4'd0;
 parameter SIGRES_FIRST_FE      = 4'd1;
 parameter SIGRES_FIRST_RE      = 4'd2;
 parameter SIGRES_SECOND_FE     = 4'd3;
 parameter SIGRES_SECOND_RE     = 4'd4;
 parameter SIGRES_THIRD_FE      = 4'd5;
 parameter SIGRES_THIRD_RE      = 4'd6;
 parameter SIGRES_FOURTH_FE      = 4'd7;
 parameter SIGRES_FOURTH_RE      = 4'd8;
 parameter SIGRES_NOT_A_RESET   = 4'd9;

 reg  [4:0]  sigres_state;

    // CS# Signaling Reset state machine
    always @(CSNeg_ipd or SI_ipd or rising_edge_SCK_ipd       or
              falling_edge_SCK_ipd  or rising_edge_CSNeg_ipd  or
              falling_edge_CSNeg_ipd)
    begin:CSNegSignalingResetStateTran

        case (sigres_state)

        SIGRES_IDLE:
        begin
            // Start check once CSNeg is asserted
            // For first CS# assertion data needs to be 1'b0.
            // ---------------------------------------------
            if ((falling_edge_CSNeg_ipd == 1'b1) && (SI_ipd == 1'b0))
                sigres_state = SIGRES_FIRST_FE;
        end

        SIGRES_FIRST_FE:  // 1st falling edge occured
        begin
            // Data needs to be constant zero during and at the end of
            // memory selection - check if this is the case
            if ((rising_edge_CSNeg_ipd == 1'b1) && (SI_ipd == 1'b0))
                sigres_state = SIGRES_FIRST_RE;
            // SI data cannot toggle during memory selection
            // SCK cannot toggle during memory selection
            else if ((rising_edge_SCK_ipd || falling_edge_SCK_ipd ||
                      (SI_ipd == 1'b1)) && (CSNeg_ipd == 1'b0))
                sigres_state = SIGRES_NOT_A_RESET;
        end

        SIGRES_FIRST_RE:  // 1st rising edge occured
        begin
            // For second CS# assertion data needs to be 1'b1.
            // ---------------------------------------------
            if ((falling_edge_CSNeg_ipd == 1'b1) && (SI_ipd == 1'b1))
                sigres_state = SIGRES_SECOND_FE;
            // SI data cannot toggle during memory selection
            // SCK cannot toggle during memory selection
            else if ((rising_edge_SCK_ipd || falling_edge_SCK_ipd ||
                      (SI_ipd == 1'b0)) && (CSNeg_ipd == 1'b0))
                sigres_state = SIGRES_NOT_A_RESET;
        end

        SIGRES_SECOND_FE:   // 2nd falling edge occured
        begin
            // Data needs to be constant one during and at the end of
            // memory selection - check if this is the case
            if ((rising_edge_CSNeg_ipd == 1'b1) && (SI_ipd == 1'b1))
                sigres_state = SIGRES_SECOND_RE;
            // SI data cannot toggle during memory selection
            // SCK cannot toggle during memory selection
            else if ((rising_edge_SCK_ipd || falling_edge_SCK_ipd ||
                      (SI_ipd == 1'b0)) && (CSNeg_ipd == 1'b0))
                sigres_state = SIGRES_NOT_A_RESET;
        end

        SIGRES_SECOND_RE:   // 2nd rising edge occured
        begin
            // For 3rd CS# assertion data needs to be 1'b0.
            // ---------------------------------------------
            if ((falling_edge_CSNeg_ipd == 1'b1) && (SI_ipd == 1'b0))
                sigres_state = SIGRES_THIRD_FE;
            // SI data cannot toggle during memory selection
            // SCK cannot toggle during memory selection
            else if ((rising_edge_SCK_ipd || falling_edge_SCK_ipd ||
                      (SI_ipd == 1'b1)) && (CSNeg_ipd == 1'b0))
                sigres_state = SIGRES_NOT_A_RESET;
        end

        SIGRES_THIRD_FE:    // 3rd falling edge occured
        begin
            // Data needs to be constant one during and at the end of
            // memory selection - check if this is the case
            if ((rising_edge_CSNeg_ipd == 1'b1) && (SI_ipd == 1'b0))
                sigres_state = SIGRES_THIRD_RE;
            // SI data cannot toggle during memory selection
            // SCK cannot toggle during memory selection
            else if ((rising_edge_SCK_ipd || falling_edge_SCK_ipd ||
                      (SI_ipd == 1'b1)) && (CSNeg_ipd == 1'b0))
                sigres_state = SIGRES_NOT_A_RESET;
        end

        SIGRES_THIRD_RE:   // 3rd rising edge occured
        begin
            // For 4th CS# assertion data needs to be 1'b1.
            // ---------------------------------------------
            if ((falling_edge_CSNeg_ipd == 1'b1) && (SI_ipd == 1'b1))
                sigres_state = SIGRES_FOURTH_FE;
            // SI data cannot toggle during memory selection
            // SCK cannot toggle during memory selection
            else if ((rising_edge_SCK_ipd || falling_edge_SCK_ipd ||
                      (SI_ipd == 1'b0)) && (CSNeg_ipd == 1'b0))
                sigres_state = SIGRES_NOT_A_RESET;
        end
        

        SIGRES_FOURTH_FE:    // 4th falling edge occured
        begin
            // Data needs to be constant one during and at the end of
            // memory selection - check if this is the case
            if ((rising_edge_CSNeg_ipd == 1'b1) && (SI_ipd == 1'b1))
                sigres_state = SIGRES_FOURTH_RE;
            // SI data cannot toggle during memory selection
            // SCK cannot toggle during memory selection
            else if ((rising_edge_SCK_ipd || falling_edge_SCK_ipd ||
                      (SI_ipd == 1'b0)) && (CSNeg_ipd == 1'b0))
                sigres_state = SIGRES_NOT_A_RESET;
        end
        

        SIGRES_FOURTH_RE:    // 4th risig edge occured
        begin
            // Final state - reset memory
                #10 RST = 1'b0;
                #10 RST = 1'b1;
                sigres_state = SIGRES_IDLE;
        end

        SIGRES_NOT_A_RESET:
        begin
            if (CSNeg_ipd == 1'b1)
                sigres_state = SIGRES_IDLE;
        end

        endcase
    end

    //Power Up time;
    initial
    begin
        PoweredUp = 1'b0;
        #tdevice_PU PoweredUp = 1'b1;
    end

    initial
    begin : Init
        integer sec_i;
        // initialize Sector Erase registers, and multi-passing register
        for (sec_i=0; sec_i<=SecNumHyb; sec_i=sec_i+1)
        begin
            SECVAL_in[sec_i]  = 23'h000000;
			SECCPT_in[sec_i]  = 1'b0;
            MPASSREG[sec_i]   = 1'b0;
        end

        write       = 1'b0;
		write_new   = 1'b0;
        cfg_write   = 1'b0;
        read_out    = 1'b0;
        Address     = 0;
        change_addr = 1'b0;
        RST         = 1'b0;
        RST_in      = 1'b0;
        RST_out     = 1'b1;
        SWRST_in    = 1'b0;
        SWRST_out   = 1'b1;
        PDONE       = 1'b1;
        PSTART      = 1'b0;
        PGSUSP      = 1'b0;
        PGRES       = 1'b0;
        PRGSUSP_in  = 1'b0;
        ERSSUSP_in  = 1'b0;
        PPBERASE_in = 1'b0;
        PASSULCK_in = 1'b0;
        RES_TO_SUSP_TIME = 1'b0;

        EDONE       = 1'b1;
        ESTART      = 1'b0;
        ESUSP       = 1'b0;
        ERES        = 1'b0;

        SEERC_DONE  = 1'b1;
        SEERC_START = 1'b0;

        CRCDONE     = 1'b1;
        CRCSTART    = 1'b0;
        CRCSUSP     = 1'b0;
        CRCRES      = 1'b0;

        WDONE       = 1'b1;
        WSTART      = 1'b0;

        DPD_in      = 1'b0;
        DPD_entered = 1'b0;
        DPD_out     = 1'b1;

        EESDONE     = 1'b1;
        EESSTART    = 1'b0;

        CSDONE      = 1'b1;
        CSSTART     = 1'b0;

        reseted     = 1'b0;

        Instruct        = NONE;
        bus_cycle_state = STAND_BY;
        current_state   = RESET_STATE;
        next_state      = RESET_STATE;
        sigres_state    = SIGRES_IDLE;
    end

    // constraint memory preload file parameters
    parameter preload_line_width    = 160;
    parameter preload_address_width = 7;
    parameter preload_data_width    = 2;

    // preload dedicated declarations
    reg [preload_line_width*8 : 1] scanf_str;
    reg [8:1] fetch_char;
    integer preload_iter;
    integer preload_file;
    integer scanf_address;
    integer scanf_data;

    // initialize memory and load preload files if any
    initial
    begin: InitMemory
        integer i;

        // memory region implicitly initialized
        memory_features_i0.initialize_w();

        if ((UserPreload) && !(mem_file_name == "none"))
        begin
           // Memory Preload
           //s28hs256m4.mem, memory preload file
           //  @aaaaaa - <aaaaaaa> stands for address
           //  dd      - <dd> is byte to be written at Mem(aaaaaa++)
           // (aaaaaa is incremented at every load)
            scanf_address = 0;
            preload_file = $fopen(mem_file_name, "r");

            while($fgets(scanf_str, preload_file))
            begin
                fetch_char = scanf_str[preload_line_width * 8 : preload_line_width * 8 - 7];

                while (!fetch_char)
                begin
                    scanf_str = scanf_str << 8;
                    fetch_char = scanf_str[preload_line_width * 8 : preload_line_width * 8 - 7];
                end

                if ((fetch_char == "/") || (fetch_char == "\n"))
                begin
                    // empty lines and comments not processed
                end
                else
                begin
                    if (fetch_char == "@")
                    begin
                        scanf_address = 0;

                        for(preload_iter = 0;
                            preload_iter < preload_address_width;
                            preload_iter = preload_iter + 1)
                        begin
                            scanf_str = scanf_str << 8;
                            fetch_char = scanf_str[preload_line_width*8 : (preload_line_width*8)-7];
                            scanf_address = scanf_address * 16;

                            if ((fetch_char >= "0")&&(fetch_char <= "9"))
                                 scanf_address = scanf_address + (fetch_char - "0");
                            else if ((fetch_char >= "A")&&(fetch_char <= "F"))
                                 scanf_address = scanf_address + (fetch_char - "A") + 10;
                            else if ((fetch_char >= "a")&&(fetch_char <= "f"))
                                 scanf_address = scanf_address + (fetch_char - "a") + 10;
                        end
                    end
                    else
                    begin
                        scanf_data = 0;
						
                        for(preload_iter = 0;
                            preload_iter < preload_data_width;
                            preload_iter = preload_iter + 1)
                        begin
                            scanf_data = scanf_data * 16;
							
                            if ((fetch_char >= "0") && (fetch_char <= "9"))
                                 scanf_data = scanf_data + (fetch_char - "0");
                            else if ((fetch_char >= "A")&&(fetch_char <= "F"))
                                 scanf_data = scanf_data + (fetch_char - "A") + 10;
                            else if ((fetch_char >= "a")&&(fetch_char <= "f"))
                                 scanf_data = scanf_data + (fetch_char - "a") + 10;

							scanf_str = scanf_str << 8;
                            fetch_char = scanf_str[preload_line_width*8 : (preload_line_width*8)-7];
                        end
						
                        if (scanf_data !== MaxData)
                        begin
                            if (scanf_address <= AddrRANGE)
                            begin
                                memory_features_i0.write_mem_w(scanf_address,scanf_data);
                            end
                            else
                                $display("Memory address out of range.");
                        end

                        scanf_address++;
                    end
                end
            end

            $fclose(preload_file);
        end

		for (i=0; i<=SecNumUni; i=i+1)
		begin
			corrupt_Sec[i] = 0;
		end

        for (i=OTPLoAddr;i<=OTPHiAddr;i=i+1)
        begin
            OTPMem[i] = MaxData;
        end

        if (UserPreload && !(otp_file_name == "none"))
        begin
        //s28hs256m4_otp memory file
        //   /        - comment
        //   @aaa - <aaa> stands for address
        //   dd  - <dd> is byte to be written at OTPMem(aaa++)
        //   (aaa is incremented at every load)
        //   only first 1-4 columns are loaded. NO empty lines !!!!!!!!!!!!!!!!
           $readmemh(otp_file_name,OTPMem);
        end

        LOCK_BYTE1[7:0] = OTPMem[16];
        LOCK_BYTE2[7:0] = OTPMem[17];
        LOCK_BYTE3[7:0] = OTPMem[18];
        LOCK_BYTE4[7:0] = OTPMem[19];
    end

    // initialize memory and load preload files if any
    initial
    begin: InitTimingModel
		integer i;
		integer j;
        //UNIFORM OR HYBRID arch model is used
        //assumptions:
        //1. TimingModel has format as s28hs512mgaXXXXXXXX_X_XXpF
        //2. TimingModel does not have more then 24 characters
        tmp_timing = TimingModel;//copy of TimingModel
        i = 23;
		
        while ((i >= 0) && (found != 1'b1))//search for first non null character
        begin        //i keeps position of first non null character
            j = 7;

            while ((j >= 0) && (found != 1'b1))
            begin
                if (tmp_timing[i*8+j] != 1'd0) found = 1'b1;
                else                               j = j-1;
            end

            i = i - 1;
        end

        i = i +1;

        if (found)//if non null character is found
        begin
            for (j=0;j<=7;j=j+1)
            begin
				//Security character is 15
                tmp_char1[j] = TimingModel[(i-13)*8+j];
            end
        end
		
        if (tmp_char1  == "V" || tmp_char1  == "A" ||
            tmp_char1  == "B" || tmp_char1  == "M")
        begin
            non_industrial_temp = 1'b1;
        end
        else if (tmp_char1 == "I")
        begin
            non_industrial_temp = 1'b0;
        end
    end

    //SFDP
    initial
    begin: InitSFDP
		integer i;
		integer j;
		integer k,l,m;

        ///////////////////////////////////////////////////////////////////////
        // SFDP Header
        ///////////////////////////////////////////////////////////////////////
        SFDP_array[16'h0000] = 8'h53;
        SFDP_array[16'h0001] = 8'h46;
        SFDP_array[16'h0002] = 8'h44;
        SFDP_array[16'h0003] = 8'h50;
        SFDP_array[16'h0004] = 8'h08;
        SFDP_array[16'h0005] = 8'h01;
        SFDP_array[16'h0006] = 8'h05;
        SFDP_array[16'h0007] = 8'hFE;
        // 1st Parameter Header
        SFDP_array[16'h0008] = 8'h00;
        SFDP_array[16'h0009] = 8'h00;
        SFDP_array[16'h000A] = 8'h01;
        SFDP_array[16'h000B] = 8'h14;
        SFDP_array[16'h000C] = 8'h00;
        SFDP_array[16'h000D] = 8'h01;
        SFDP_array[16'h000E] = 8'h00;
        SFDP_array[16'h000F] = 8'hFF;
        // 2nd Parameter Header
        SFDP_array[16'h0010] = 8'h84;
        SFDP_array[16'h0011] = 8'h00;
        SFDP_array[16'h0012] = 8'h01;
        SFDP_array[16'h0013] = 8'h02;
        SFDP_array[16'h0014] = 8'h50;
        SFDP_array[16'h0015] = 8'h01;
        SFDP_array[16'h0016] = 8'h00;
        SFDP_array[16'h0017] = 8'hFF;
        // 3rd Parameter Header
        SFDP_array[16'h0018] = 8'h05;
        SFDP_array[16'h0019] = 8'h00;
        SFDP_array[16'h001A] = 8'h01;
        SFDP_array[16'h001B] = 8'h05;
        SFDP_array[16'h001C] = 8'h58;
        SFDP_array[16'h001D] = 8'h01;
        SFDP_array[16'h001E] = 8'h00;
        SFDP_array[16'h001F] = 8'hFF;
        // 4th Parameter Header
        SFDP_array[16'h0020] = 8'h87;
        SFDP_array[16'h0021] = 8'h00;
        SFDP_array[16'h0022] = 8'h01;
        SFDP_array[16'h0023] = 8'h1C;
        SFDP_array[16'h0024] = 8'h6C;
        SFDP_array[16'h0025] = 8'h01;
        SFDP_array[16'h0026] = 8'h00;
        SFDP_array[16'h0027] = 8'hFF;
        // 5th Parameter Header
        SFDP_array[16'h0028] = 8'h0A;
        SFDP_array[16'h0029] = 8'h00;
        SFDP_array[16'h002A] = 8'h01;
        SFDP_array[16'h002B] = 8'h04;
        SFDP_array[16'h002C] = 8'hDC;
        SFDP_array[16'h002D] = 8'h01;
        SFDP_array[16'h002E] = 8'h00;
        SFDP_array[16'h002F] = 8'hFF;
        // 6th Parameter Header
        SFDP_array[16'h0030] = 8'h81;
        SFDP_array[16'h0031] = 8'h00;
        SFDP_array[16'h0032] = 8'h01;
        SFDP_array[16'h0033] = 8'h16;
        SFDP_array[16'h0034] = 8'hEC;
        SFDP_array[16'h0035] = 8'h01;
        SFDP_array[16'h0036] = 8'h00;
        SFDP_array[16'h0037] = 8'hFF;
//         // 7th Parameter Header
//         SFDP_array[16'h0038] = 8'h09;
//         SFDP_array[16'h0039] = 8'h00;
//         SFDP_array[16'h003A] = 8'h01;
//         SFDP_array[16'h003B] = 8'h04;
//         SFDP_array[16'h003C] = 8'h14;
//         SFDP_array[16'h003D] = 8'h02;
//         SFDP_array[16'h003E] = 8'h00;
//         SFDP_array[16'h003F] = 8'hFF;

        // Unused
        for (i=16'h0038;i< 16'h0100;i=i+1)
        begin
           SFDP_array[i]=MaxData;
        end

        ///////////////////////////////////////////////////////////////////////
        // JEDEC Basic Flash Parameters
        ///////////////////////////////////////////////////////////////////////
        // DWORD-1
        SFDP_array[16'h0100] = 8'hF7;
        SFDP_array[16'h0101] = 8'h21;
        SFDP_array[16'h0102] = 8'h8A;
        SFDP_array[16'h0103] = 8'hFF;
        // DWORD-2
        SFDP_array[16'h0104] = 8'hFF;
        SFDP_array[16'h0105] = 8'hFF;
        SFDP_array[16'h0106] = 8'hFF;
        SFDP_array[16'h0107] = 8'h1F; //512
        // DWORD-3
        SFDP_array[16'h0108] = 8'h00;
        SFDP_array[16'h0109] = 8'h00;
        SFDP_array[16'h010A] = 8'h00;
        SFDP_array[16'h010B] = 8'h00;
        // DWORD-4
        SFDP_array[16'h010C] = 8'h00;
        SFDP_array[16'h010D] = 8'h00;
        SFDP_array[16'h010E] = 8'h00;
        SFDP_array[16'h010F] = 8'h00;
        // DWORD-5
        SFDP_array[16'h0110] = 8'hEE;
        SFDP_array[16'h0111] = 8'hFF;
        SFDP_array[16'h0112] = 8'hFF;
        SFDP_array[16'h0113] = 8'hFF;
        // DWORD-6
        SFDP_array[16'h0114] = 8'hFF;
        SFDP_array[16'h0115] = 8'hFF;
        SFDP_array[16'h0116] = 8'h00;
        SFDP_array[16'h0117] = 8'h00;
        // DWORD-7
        SFDP_array[16'h0118] = 8'hFF;
        SFDP_array[16'h0119] = 8'hFF;
        SFDP_array[16'h011A] = 8'h00;
        SFDP_array[16'h011B] = 8'h00;
        // DWORD-8
        SFDP_array[16'h011C] = 8'h0C;
        SFDP_array[16'h011D] = 8'h21;
        SFDP_array[16'h011E] = 8'h00;
        SFDP_array[16'h011F] = 8'hFF;
        // DWORD-9
        SFDP_array[16'h0120] = 8'h00;
        SFDP_array[16'h0121] = 8'hFF;
        SFDP_array[16'h0122] = 8'h12;
        SFDP_array[16'h0123] = 8'hDC;
        // DWORD-10
        SFDP_array[16'h0124] = 8'h23;
        SFDP_array[16'h0125] = 8'hFA;
        SFDP_array[16'h0126] = 8'hFF;
        SFDP_array[16'h0127] = 8'h8B;
        // DWORD-11
        SFDP_array[16'h0128] = 8'h82;
        SFDP_array[16'h0129] = 8'hE7;
        SFDP_array[16'h012A] = 8'hFF;
        SFDP_array[16'h012B] = 8'hE3; //512
        // DWORD-12
        SFDP_array[16'h012C] = 8'hEC;
        SFDP_array[16'h012D] = 8'h23;
        SFDP_array[16'h012E] = 8'h19;
        SFDP_array[16'h012F] = 8'h49;
        // DWORD-13
        SFDP_array[16'h0130] = 8'h7A;
        SFDP_array[16'h0131] = 8'hB0;
        SFDP_array[16'h0132] = 8'h7A;
        SFDP_array[16'h0133] = 8'hB0;
        // DWORD-14
        SFDP_array[16'h0134] = 8'hF7;
        SFDP_array[16'h0135] = 8'h66;
        SFDP_array[16'h0136] = 8'h80;
        SFDP_array[16'h0137] = 8'h5C;
        // DWORD-15
        SFDP_array[16'h0138] = 8'h00;
        SFDP_array[16'h0139] = 8'h00;
        SFDP_array[16'h013A] = 8'h00;
        SFDP_array[16'h013B] = 8'hFF;
        // DWORD-16
        SFDP_array[16'h013C] = 8'hF9;
        SFDP_array[16'h013D] = 8'h10;
        SFDP_array[16'h013E] = 8'hF8;
        SFDP_array[16'h013F] = 8'hA1; 
        // DWORD-17
        SFDP_array[16'h0140] = 8'h00;
        SFDP_array[16'h0141] = 8'h00;
        SFDP_array[16'h0142] = 8'h00;
        SFDP_array[16'h0143] = 8'h00;
        // DWORD-18
        SFDP_array[16'h0144] = 8'h00;
        SFDP_array[16'h0145] = 8'h00;
        SFDP_array[16'h0146] = 8'hBC;
        SFDP_array[16'h0147] = 8'h02;
        // DWORD-19
        SFDP_array[16'h0148] = 8'h00;
        SFDP_array[16'h0149] = 8'h00;
        SFDP_array[16'h014A] = 8'h00;
        SFDP_array[16'h014B] = 8'h00;
        // DWORD-20
        SFDP_array[16'h014C] = 8'hFF;
        SFDP_array[16'h014D] = 8'hFF;
        SFDP_array[16'h014E] = 8'h8E; //HS
        SFDP_array[16'h014F] = 8'h8E; //HS

        // JEDEC 4-Byte Address Instructions Parameter DWORD-1
        SFDP_array[16'h0150] = 8'h41;
        SFDP_array[16'h0151] = 8'h12;
        SFDP_array[16'h0152] = 8'h0F;
        SFDP_array[16'h0153] = 8'hFE;
        // JEDEC 4-Byte Address Instructions Parameter DWORD-2
        SFDP_array[16'h0154] = 8'h21;
        SFDP_array[16'h0155] = 8'hFF;
        SFDP_array[16'h0156] = 8'hFF;
        SFDP_array[16'h0157] = 8'hDC;

        // JEDEC xSPI Profile 1.0 DWORD-1
        SFDP_array[16'h0158] = 8'h00;
        SFDP_array[16'h0159] = 8'hEE;
        SFDP_array[16'h015A] = 8'h80;
        SFDP_array[16'h015B] = 8'h0B; 
        // JEDEC xSPI Profile 1.0 DWORD-2
        SFDP_array[16'h015C] = 8'h71; 
        SFDP_array[16'h015D] = 8'h71; 
        SFDP_array[16'h015E] = 8'h65; 
        SFDP_array[16'h015F] = 8'h65; 
        // JEDEC xSPI Profile 1.0 DWORD-3
        SFDP_array[16'h0160] = 8'h00;
        SFDP_array[16'h0161] = 8'hB0;
        SFDP_array[16'h0162] = 8'hFF; 
        SFDP_array[16'h0163] = 8'h96; 
        // JEDEC xSPI Profile 1.0 DWORD-4
        SFDP_array[16'h0164] = 8'hA8;
        SFDP_array[16'h0165] = 8'h0B;
        SFDP_array[16'h0166] = 8'h00;
        SFDP_array[16'h0167] = 8'h00;

        // JEDEC xSPI Profile 1.0 DWORD-5
        SFDP_array[16'h0168] = 8'h0C;
        SFDP_array[16'h0169] = 8'h55;
        SFDP_array[16'h016A] = 8'h1C;
        SFDP_array[16'h016B] = 8'hA2;

        // Status, Control and Configuration Register Map DWORD-1
        SFDP_array[16'h016C] = 8'h00;
        SFDP_array[16'h016D] = 8'h00;
        SFDP_array[16'h016E] = 8'h80;
        SFDP_array[16'h016F] = 8'h00;
        // Status, Control and Configuration Register Map DWORD-2
        SFDP_array[16'h0170] = 8'h00;
        SFDP_array[16'h0171] = 8'h00;
        SFDP_array[16'h0172] = 8'h00;
        SFDP_array[16'h0173] = 8'h00;
        // Status, Control and Configuration Register Map DWORD-3
        SFDP_array[16'h0174] = 8'hC0;
        SFDP_array[16'h0175] = 8'hCC;
        SFDP_array[16'h0176] = 8'hFF;
        SFDP_array[16'h0177] = 8'hEB;
        // Status, Control and Configuration Register Map DWORD-4
        SFDP_array[16'h0178] = 8'h88;
        SFDP_array[16'h0179] = 8'hFB;
        SFDP_array[16'h017A] = 8'hFF;
        SFDP_array[16'h017B] = 8'hEB;
        // Status, Control and Configuration Register Map DWORD-5
        SFDP_array[16'h017C] = 8'h00;
        SFDP_array[16'h017D] = 8'h65;
        SFDP_array[16'h017E] = 8'h00;
        SFDP_array[16'h017F] = 8'h90;
        // Status, Control and Configuration Register Map DWORD-6
        SFDP_array[16'h0180] = 8'h06;
        SFDP_array[16'h0181] = 8'h65;
        SFDP_array[16'h0182] = 8'h00;
        SFDP_array[16'h0183] = 8'hA1;
        // Status, Control and Configuration Register Map DWORD-7
        SFDP_array[16'h0184] = 8'h00;
        SFDP_array[16'h0185] = 8'h65;
        SFDP_array[16'h0186] = 8'h00;
        SFDP_array[16'h0187] = 8'h96;
        // Status, Control and Configuration Register Map DWORD-8
        SFDP_array[16'h0188] = 8'h00;
        SFDP_array[16'h0189] = 8'h65;
        SFDP_array[16'h018A] = 8'h00;
        SFDP_array[16'h018B] = 8'h95;
        // Status, Control and Configuration Register Map DWORD-9
        SFDP_array[16'h018C] = 8'h71;
        SFDP_array[16'h018D] = 8'h65;
        SFDP_array[16'h018E] = 8'h03;
        SFDP_array[16'h018F] = 8'hD0;
        // Status, Control and Configuration Register Map DWORD-10
        SFDP_array[16'h0190] = 8'h71;
        SFDP_array[16'h0191] = 8'h65;
        SFDP_array[16'h0192] = 8'h03;
        SFDP_array[16'h0193] = 8'hD0;
        // Status, Control and Configuration Register Map DWORD-11
        SFDP_array[16'h0194] = 8'hA4;
        SFDP_array[16'h0195] = 8'h6B;
        SFDP_array[16'h0196] = 8'hFB;
        SFDP_array[16'h0197] = 8'h02;
        // Status, Control and Configuration Register Map DWORD-12
        SFDP_array[16'h0198] = 8'h90;
        SFDP_array[16'h0199] = 8'hA5;
        SFDP_array[16'h019A] = 8'h79;
        SFDP_array[16'h019B] = 8'hA2;
        // Status, Control and Configuration Register Map DWORD-13
        SFDP_array[16'h019C] = 8'h00;
        SFDP_array[16'h019D] = 8'h40;
        SFDP_array[16'h019E] = 8'h28;
        SFDP_array[16'h019F] = 8'h8E;
        // Status, Control and Configuration Register Map DWORD-14
        SFDP_array[16'h01A0] = 8'h00;
        SFDP_array[16'h01A1] = 8'h00;
        SFDP_array[16'h01A2] = 8'hFF;
        SFDP_array[16'h01A3] = 8'h00;
        // Status, Control and Configuration Register Map DWORD-15
        SFDP_array[16'h01A4] = 8'h00;
        SFDP_array[16'h01A5] = 8'h00;
        SFDP_array[16'h01A6] = 8'hFF;
        SFDP_array[16'h01A7] = 8'h00;
        // Status, Control and Configuration Register Map DWORD-16
        SFDP_array[16'h01A8] = 8'h71;
        SFDP_array[16'h01A9] = 8'h65;
        SFDP_array[16'h01AA] = 8'h06;
        SFDP_array[16'h01AB] = 8'h90;
        // Status, Control and Configuration Register Map DWORD-17
        SFDP_array[16'h01AC] = 8'h71;
        SFDP_array[16'h01AD] = 8'h65;
        SFDP_array[16'h01AE] = 8'h06;
        SFDP_array[16'h01AF] = 8'h90;
        // Status, Control and Configuration Register Map DWORD-18
        SFDP_array[16'h01B0] = 8'h00;
        SFDP_array[16'h01B1] = 8'h00;
        SFDP_array[16'h01B2] = 8'h00;
        SFDP_array[16'h01B3] = 8'h00;
        // Status, Control and Configuration Register Map DWORD-19
        SFDP_array[16'h01B4] = 8'h00;
        SFDP_array[16'h01B5] = 8'h00;
        SFDP_array[16'h01B6] = 8'h00;
        SFDP_array[16'h01B7] = 8'h00;
        // Status, Control and Configuration Register Map DWORD-20
        SFDP_array[16'h01B8] = 8'h71;
        SFDP_array[16'h01B9] = 8'h65;
        SFDP_array[16'h01BA] = 8'h06;
        SFDP_array[16'h01BB] = 8'hD1;
        // Status, Control and Configuration Register Map DWORD-21
        SFDP_array[16'h01BC] = 8'h71;
        SFDP_array[16'h01BD] = 8'h65;
        SFDP_array[16'h01BE] = 8'h06;
        SFDP_array[16'h01BF] = 8'hD1;
        // Status, Control and Configuration Register Map DWORD-22
        SFDP_array[16'h01C0] = 8'h71;
        SFDP_array[16'h01C1] = 8'h65;
        SFDP_array[16'h01C2] = 8'h06;
        SFDP_array[16'h01C3] = 8'h91;
        // Status, Control and Configuration Register Map DWORD-23
        SFDP_array[16'h01C4] = 8'h71;
        SFDP_array[16'h01C5] = 8'h65;
        SFDP_array[16'h01C6] = 8'h06;
        SFDP_array[16'h01C7] = 8'h91;
        // Status, Control and Configuration Register Map DWORD-24
        SFDP_array[16'h01C8] = 8'h00;
        SFDP_array[16'h01C9] = 8'h00;
        SFDP_array[16'h01CA] = 8'hFF;
        SFDP_array[16'h01CB] = 8'h00;
        // Status, Control and Configuration Register Map DWORD-25
        SFDP_array[16'h01CC] = 8'h00;
        SFDP_array[16'h01CD] = 8'h00;
        SFDP_array[16'h01CE] = 8'hFF;
        SFDP_array[16'h01CF] = 8'h00;
        // Status, Control and Configuration Register Map DWORD-26
        SFDP_array[16'h01D0] = 8'h71;
        SFDP_array[16'h01D1] = 8'h65;
        SFDP_array[16'h01D2] = 8'h05;
        SFDP_array[16'h01D3] = 8'hD5;
        // Status, Control and Configuration Register Map DWORD-27
        SFDP_array[16'h01D4] = 8'h71;
        SFDP_array[16'h01D5] = 8'h65;
        SFDP_array[16'h01D6] = 8'h05;
        SFDP_array[16'h01D7] = 8'hD5;
        // Status, Control and Configuration Register Map DWORD-28
        SFDP_array[16'h01D8] = 8'h00;
        SFDP_array[16'h01D9] = 8'h00;
        SFDP_array[16'h01DA] = 8'hA0;
        SFDP_array[16'h01DB] = 8'h15;

        ///////////////////////////////////////////////////////////////////////
        // Command Sequences to Change to Octal DDR mode
        ///////////////////////////////////////////////////////////////////////
        // DWORD-1
        SFDP_array[16'h01DC] = 8'h00;
        SFDP_array[16'h01DD] = 8'h00;
        SFDP_array[16'h01DE] = 8'h06;
        SFDP_array[16'h01DF] = 8'h01;
        // DWORD-2
        SFDP_array[16'h01E0] = 8'h00;
        SFDP_array[16'h01E1] = 8'h00;
        SFDP_array[16'h01E2] = 8'h00;
        SFDP_array[16'h01E3] = 8'h00;
        // DWORD-3
        SFDP_array[16'h01E4] = 8'h00;
        SFDP_array[16'h01E5] = 8'h80;
        SFDP_array[16'h01E6] = 8'h71;
        SFDP_array[16'h01E7] = 8'h05;
        // DWORD-4
        SFDP_array[16'h01E8] = 8'h00;
        SFDP_array[16'h01E9] = 8'h00;
        SFDP_array[16'h01EA] = 8'h43;
        SFDP_array[16'h01EB] = 8'h06;
        
        ///////////////////////////////////////////////////////////////////////
        // Command Sequences to Change to Octal DDR mode
        ///////////////////////////////////////////////////////////////////////
        // Sector Map DWORD-1
        SFDP_array[16'h01EC] = 8'hFC;
        SFDP_array[16'h01ED] = 8'h65;
        SFDP_array[16'h01EE] = 8'hFF;
        SFDP_array[16'h01EF] = 8'h08;
        // Sector Map DWORD-2
        SFDP_array[16'h01F0] = 8'h04;
        SFDP_array[16'h01F1] = 8'h00;
        SFDP_array[16'h01F2] = 8'h80;
        SFDP_array[16'h01F3] = 8'h00;

        // Sector Map DWORD-3
        SFDP_array[16'h01F4] = 8'hFC;
        SFDP_array[16'h01F5] = 8'h65;
        SFDP_array[16'h01F6] = 8'hFF;
        SFDP_array[16'h01F7] = 8'h40;
        // Sector Map DWORD-4
        SFDP_array[16'h01F8] = 8'h02;
        SFDP_array[16'h01F9] = 8'h00;
        SFDP_array[16'h01FA] = 8'h80;
        SFDP_array[16'h01FB] = 8'h00;
        // Sector Map DWORD-5
        SFDP_array[16'h01FC] = 8'hFD;
        SFDP_array[16'h01FD] = 8'h65;
        SFDP_array[16'h01FE] = 8'hFF;
        SFDP_array[16'h01FF] = 8'h04;
        // Sector Map DWORD-6
        SFDP_array[16'h0200] = 8'h02;
        SFDP_array[16'h0201] = 8'h00;
        SFDP_array[16'h0202] = 8'h80;
        SFDP_array[16'h0203] = 8'h00;
        // Sector Map DWORD-7
        SFDP_array[16'h0204] = 8'hFE;
        SFDP_array[16'h0205] = 8'h00;
        SFDP_array[16'h0206] = 8'h02;
        SFDP_array[16'h0207] = 8'hFF;
        // Sector Map DWORD-8
        SFDP_array[16'h0208] = 8'hF1;
        SFDP_array[16'h0209] = 8'hFF;
        SFDP_array[16'h020A] = 8'h01;
        SFDP_array[16'h020B] = 8'h00;
        // Sector Map DWORD-9
        SFDP_array[16'h020C] = 8'hF8;
        SFDP_array[16'h020D] = 8'hFF;
        SFDP_array[16'h020E] = 8'h01;
        SFDP_array[16'h020F] = 8'h00;
        // Sector Map DWORD-10
        SFDP_array[16'h0210] = 8'hF8;
        SFDP_array[16'h0211] = 8'hFF;
        SFDP_array[16'h0212] = 8'hFB; //512
        SFDP_array[16'h0213] = 8'h03; //512
        //  Sector Map DWORD-11
        SFDP_array[16'h0214] = 8'hFE;
        SFDP_array[16'h0215] = 8'h01;
        SFDP_array[16'h0216] = 8'h02;
        SFDP_array[16'h0217] = 8'hFF;
        //  Sector Map DWORD-12
        SFDP_array[16'h0218] = 8'hF8;
        SFDP_array[16'h0219] = 8'hFF;
        SFDP_array[16'h021A] = 8'hFB; //512
        SFDP_array[16'h021B] = 8'h03; //512
        //  Sector Map DWORD-13
        SFDP_array[16'h021C] = 8'hF8;
        SFDP_array[16'h021D] = 8'hFF;
        SFDP_array[16'h021E] = 8'h01;
        SFDP_array[16'h021F] = 8'h00; 
        //  Sector Map DWORD-14
        SFDP_array[16'h0220] = 8'hF1;
        SFDP_array[16'h0221] = 8'hFF; 
        SFDP_array[16'h0222] = 8'h01;
        SFDP_array[16'h0223] = 8'h00;
        //  Sector Map DWORD-15
        SFDP_array[16'h0224] = 8'hFE; 
        SFDP_array[16'h0225] = 8'h02;
        SFDP_array[16'h0226] = 8'h04;
        SFDP_array[16'h0227] = 8'hFF;
        //  Sector Map DWORD-16
        SFDP_array[16'h0228] = 8'hF1;
        SFDP_array[16'h0229] = 8'hFF; 
        SFDP_array[16'h022A] = 8'h00; 
        SFDP_array[16'h022B] = 8'h00;
        //  Sector Map DWORD-17
        SFDP_array[16'h022C] = 8'hF8;
        SFDP_array[16'h022D] = 8'hED; 
        SFDP_array[16'h022E] = 8'h02;
        SFDP_array[16'h022F] = 8'h00;
        //  Sector Map DWORD-18
        SFDP_array[16'h0230] = 8'hF8;
        SFDP_array[16'h0231] = 8'hFF; 
        SFDP_array[16'h0232] = 8'hF7; //512 
        SFDP_array[16'h0233] = 8'h03; //512
        //  Sector Map DWORD-19
        SFDP_array[16'h0234] = 8'hF8;
        SFDP_array[16'h0235] = 8'hFF; 
        SFDP_array[16'h0236] = 8'h02;
        SFDP_array[16'h0237] = 8'h00;
        //  Sector Map DWORD-20
        SFDP_array[16'h0238] = 8'hF1;
        SFDP_array[16'h0239] = 8'hFF; 
        SFDP_array[16'h023A] = 8'h00; 
        SFDP_array[16'h023B] = 8'h00;
        //  Sector Map DWORD-21
        SFDP_array[16'h023C] = 8'hFF;
        SFDP_array[16'h023D] = 8'h04;
        SFDP_array[16'h023E] = 8'h00;
        SFDP_array[16'h023F] = 8'hFF;
        //  Sector Map DWORD-22
        SFDP_array[16'h0240] = 8'hF8;
        SFDP_array[16'h0241] = 8'hFF;
        SFDP_array[16'h0242] = 8'hFF; //512 
        SFDP_array[16'h0243] = 8'h03; //512

        for(l=SFDPHiAddr;l>=0;l=l-1)
        begin
            SFDP_tmp = SFDP_array[SFDPLength-l];

            for(m=7;m>=0;m=m-1)
            begin
                SFDP_array_tmp[8*l+m] = SFDP_tmp[m];
            end
        end

    end

    always @(next_state or PoweredUp or falling_edge_RST or RST_out or SWRST_out )
    begin: StateTransition1
        if (PoweredUp)
        begin
            if (falling_edge_RST)
            begin
            // no state transition while RESET# low
                current_state = RESET_STATE;
                sigres_state  = SIGRES_IDLE;
                RST_in = 1'b1;
                #1 RST_in = 1'b0;
                reseted   = 1'b0;
            end
            else if (RST_out && SWRST_out)
            begin
                current_state = next_state;
                reseted = 1;
            end
        end
    end

    always @(falling_edge_write)
    begin: StateTransition2
        if (Instruct == SFRST_0_0 && RESET_EN)
        begin
            // no state transition while RESET is in progress
            current_state = RESET_STATE;
            sigres_state  = SIGRES_IDLE;
            SWRST_in = 1'b1;
            #1 SWRST_in = 1'b0;
            reseted   = 1'b0;
            RESET_EN = 0;
        end
    end

always @(ICRCDL) begin
	case(ICRCDL)
	2'b00: sgm_size = 16;
	2'b01: sgm_size = 32;
	2'b10: sgm_size = 64;
	2'b11: sgm_size = 128;
	endcase

	if(ITCRCE && QPI_IT && SDRDDR) 
		crc_pageBytes = (PageSize+1)/(2*sgm_size); 
	else if(ITCRCE) 
	    crc_pageBytes = (PageSize+1)/(sgm_size); 
	else 
	    crc_pageBytes = 0;
end

    ////////////////////////////////////////////////////////////////////////////
    // Timing control for the Hardware Reset
    ////////////////////////////////////////////////////////////////////////////
    always @(posedge RST_in)
    begin:Threset
        RST_out = 1'b0;
        #(tdevice_RPH -200000) RST_out = 1'b1;
    end

    always @(RESETNeg)
        begin
        RST <= #199000 RESETNeg;
    end

    ////////////////////////////////////////////////////////////////////////////
    // Timing control for the Software Reset
    ////////////////////////////////////////////////////////////////////////////
    always @(posedge SWRST_in)
    begin:Tswreset
        SWRST_out = 1'b0;
        #tdevice_SR SWRST_out = 1'b1;
    end

    always @(negedge CSNeg_ipd)
    begin:CheckCSOnPowerUP
        if (~PoweredUp)
            $display ("Device is selected during Power Up");
    end

    ///////////////////////////////////////////////////////////////////////////
    //// Internal Delays
    ///////////////////////////////////////////////////////////////////////////

    always @(posedge PRGSUSP_in)
    begin:PRGSuspend
        PRGSUSP_out = 1'b0;
        #tdevice_SUSP PRGSUSP_out = 1'b1;
    end

    always @(posedge ERSSUSP_in)
    begin:ERSSuspend
        ERSSUSP_out = 1'b0;
        #tdevice_SUSP ERSSUSP_out = 1'b1;
    end

    always @(posedge PPBERASE_in)
    begin:PPBErs
        PPBERASE_out = 1'b0;
        #tdevice_SE4 PPBERASE_out = 1'b1;
    end

    always @(posedge PASSULCK_in)
    begin:PASSULock
        PASSULCK_out = 1'b0;
        #tdevice_PP_256 PASSULCK_out = 1'b1;
    end

    always @(posedge PASSACC_in)
    begin:PASSAcc
        PASSACC_out = 1'b0;
        #tdevice_PASSACC PASSACC_out = 1'b1;
    end

    always @(CSNeg_ipd or rising_edge_SCK_ipd or falling_edge_SCK_ipd)
    begin : icrc_calc_proc
        integer j;

        if (ITCRCE == 0 && SDRDDR == 1'b1 && QPI_IT && RST_out && ICRC_DATA)
        begin
            if (CSNeg_ipd == 1'b0 &&  rd_crc == 0) // if memory is selected and not RDCRC_4_0 command
            begin
                if ((rising_edge_SCK_ipd || falling_edge_SCK_ipd))// if complete 16 bit data is captured
                begin
                    cnt_icrc32 = cnt_icrc32 + 1;

                    if (cnt_icrc32%4 == 0)
                    begin
                        icrc_in[7:0] = Din;
                    end
                    else if (cnt_icrc32%4 == 1)
                    begin
                         icrc_in[15:8] = Din;
                    end
                    else if  (cnt_icrc32%4 == 2)
                    begin
                        icrc_in[23:16] = Din;
                    end
                    else if  (cnt_icrc32%4 == 3)
                    begin
                        icrc_in[31:24] = Din;
                        icrc_cnt = icrc_cnt + 1;

                        for(j=31;j>=0;j=j-1)
                        begin
                            icrc_tmp = icrc_in[j] ^ icrc_out[31];
                            icrc_out[31]  = icrc_out[30];
                            icrc_out[30]  = icrc_out[29];
                            icrc_out[29]  = icrc_out[28];
                            icrc_out[28]  = icrc_out[27]  ^ icrc_tmp;
                            icrc_out[27]  = icrc_out[26]  ^ icrc_tmp;
                            icrc_out[26]  = icrc_out[25]  ^ icrc_tmp;
                            icrc_out[25]  = icrc_out[24]  ^ icrc_tmp;
                            icrc_out[24]  = icrc_out[23];
                            icrc_out[23]  = icrc_out[22]  ^ icrc_tmp;
                            icrc_out[22]  = icrc_out[21]  ^ icrc_tmp;
                            icrc_out[21]  = icrc_out[20];
                            icrc_out[20]  = icrc_out[19]  ^ icrc_tmp;
                            icrc_out[19]  = icrc_out[18]  ^ icrc_tmp;
                            icrc_out[18]  = icrc_out[17]  ^ icrc_tmp;
                            icrc_out[17]  = icrc_out[16];
                            icrc_out[16]  = icrc_out[15];
                            icrc_out[15]  = icrc_out[14];
                            icrc_out[14]  = icrc_out[13]  ^ icrc_tmp;
                            icrc_out[13]  = icrc_out[12]  ^ icrc_tmp;
                            icrc_out[12]  = icrc_out[11];
                            icrc_out[11]  = icrc_out[10]  ^ icrc_tmp;
                            icrc_out[10]  = icrc_out[9]   ^ icrc_tmp;
                            icrc_out[9]   = icrc_out[8]   ^ icrc_tmp;
                            icrc_out[8]   = icrc_out[7]   ^ icrc_tmp;
                            icrc_out[7]   = icrc_out[6];
                            icrc_out[6]   = icrc_out[5]   ^ icrc_tmp;
                            icrc_out[5]   = icrc_out[4];
                            icrc_out[4]   = icrc_out[3];
                            icrc_out[3]   = icrc_out[2];
                            icrc_out[2]   = icrc_out[1];
                            icrc_out[1]   = icrc_out[0];
                            icrc_out[0]   = icrc_tmp;
                        end
                    end
                end

                if (icrc_cnt >= 4) ICRV = icrc_out;
                else               ICRV = ICRV;
            end
        end
    end
    


    // ------------------------------------------------------------------------
    // Deep Power Down time
    // ------------------------------------------------------------------------
    // DPDExit_in is any write or read access for which CSNeg_ipd is asserted
    // more than tDPDCSL time. No exit event is detected until DPD is entered,
    // which is after tENTDPD
    assign DPDExt_in = ((falling_edge_CSNeg_ipd == 1'b1) && (DPD_entered == 1'b1)) ?
                         1'b1 : 1'b0;

    always @(posedge DPDExt_in)
    begin : DPDExtEvent
      #(tdevice_CSDPD - 1) DPDExt_out = 1'b1;
    end

    // DPD entry event, generated after tENTDPD time (minumum 3 us)
    // While entering DPD memory is not accessable so DPD exit event cannot be generated
    always @(posedge DPD_in)
    begin : DPDEntEvent
      #(tdevice_ENTDPD - 1) DPD_entered = 1'b1;
    end

    // Generate event to trigger exiting from DPD mode
    always @(posedge DPDExt_out or CSNeg_ipd or RESETNeg or falling_edge_RST or
             DPD_in)
    begin : DPDExtDetected
      if ((DPDExt_out == 1'b1) && (CSNeg_ipd == 1'b0) || 
          (falling_edge_RST && DPD_in))
      begin
        DPDExt = 1'b1;
        #1 DPDExt = 1'b0;
      end
    end

    // DPD exit event, generated after tDPDOUT time (maximal: 300 us)
    always @(posedge DPDExt)
    begin : DPDExtTime
        DPD_out = 1'b0;
        #(tdevice_EXTDPD - 1) DPD_out = 1'b1;
    end
    
    always @(posedge PoweredUp or posedge RST_in)
    begin:DPDown_POR
        DPD_POR_out = 1'b0;
        #tdevice_PU DPD_POR_out = 1'b1;
    end

///////////////////////////////////////////////////////////////////////////////
// write cycle decode
///////////////////////////////////////////////////////////////////////////////
    integer opcode_cnt = 0;
    integer addr_cnt   = 0;
    integer mode_cnt   = 0;
    integer data_cnt   = 0;
    integer bit_cnt    = 0;
	integer crc_cnt    = 0; 
	integer crc_sgm_cnt = 0;  // CRC segment count
	integer crc_drp_cnt = 0;
	integer intermediate = 0;
	reg     even        = 0;
	reg     first_rd_byte   = 1;

    reg [4095:0] Data_in = {4096{1'b1}};
	wire [4095:0] Data_inR;
	wire [31:0]  Address_inR;

	
    reg    [7:0] opcode;
    reg    [7:0] opcode_in;
    reg    [7:0] opcode_tmp;
    reg   [31:0] addr_bytes;
    reg   [31:0] hiaddr_bytes;
    reg   [31:0] Address_in;
    reg    [7:0] mode_bytes;
    reg    [7:0] mode_in;
    integer Latency_code;
    integer Register_Latency = 4;
	reg [3:0] quad_byte = 4'b0;
    reg [3:0] quad_data_in [0:1023];
    reg [3:0] quad_nibble = 4'b0;
	reg [3:0] Quad_slv;
	
	reg [7:0] current_bytei = 8'b0;
    reg [7:0] current_byte = 8'b0;
	assign   Data_inR = {<<{Data_in}}; // Reverse waveform display
	assign   Address_inR = {<<{Address_in}}; // Reverse waveform display
	
    reg [7:0] Byte_slv;

    reg CRC_ACT      = 1'b0; // CRC Active
    reg CRC_RD_SETUP = 1'b0; // CRC read setup
    reg [15:0] crc_in;
    reg [31:0] crc_out;
    reg crc_tmp;
	
	
	// CRC Polynomial: x^8 + x^4 + x^3 + x^2 + 1 (0x1D)
    parameter [7:0] polynomial8 = 8'h1D;
	parameter [15:0] polynomial16 = 816'h1021;
	reg [7:0]  crc_reg8_cmd = 8'hFF;
    reg [7:0]  crc_reg8_data = 8'hFF;
	reg [7:0]  crc_reg8_pgm_data = 8'hFF;
    reg [15:0] crc_reg16_cmd = 16'hFFFF;
	reg [15:0] crc_reg16_data = 16'hFFFF;
	reg [15:0] crc_reg16_pgm_data = 16'hFFFF;
	
	reg        change_crc; //what is this for?
	reg        crc_pass_cmd = 1;
	reg        crc_pass_pgm = 1;
	reg [15:0] Intfcrc_in; 
	reg [15:0] Intfcrc_value; 
    
    
    ///////////////////////////////////////////////////////////////////////////
    // Process that determines clock frequency
    ///////////////////////////////////////////////////////////////////////////
     always @(rising_edge_SCK_ipd or CSNeg_ipd)
     begin : check_freq
        time CK_PER_freq;
        time LAST_CK_freq;
        CK_PER_freq = $time - LAST_CK_freq;
        LAST_CK_freq = $time;
        # 1;
        
        if (CSNeg_ipd)
           counter_clock = 3'b000;
        else if (counter_clock < 3'b111)
           counter_clock = counter_clock + 1;
        else 
           counter_clock = 3'b111;
            
        if (CK_PER_freq < 20000 || counter_clock < 3'b010 )
           freq51 = 1'b1;
        else 
           freq51 = 1'b0;
     end 
     
    ///////////////////////////////////////////////////////////////////////////
    // Process for Data Strobe / DS
    ///////////////////////////////////////////////////////////////////////////
     always @(CSNeg_ipd or QPI_IT or SDRDDR)
     begin : check_DS
        
        if (~CSNeg_ipd)
        begin
			if (QPI_IT)
			begin
				DATA_STROBE = CFR5V[7];
			end
			else
			begin
				//1-1-4 and 1-4-4 are exceptions. Will be set after instruction received
				DATA_STROBE = 1'b0;
			end
        end
        else
        begin
            DATA_STROBE = 1'b0;
        end
     end 

	reg [7:0]  crc8_result;

	task CALC_CRC8;  //For CRC8
		input   [7:0] data_in;
		integer i;
        begin
				crc8_result = crc8_result ^ data_in;

				for (i = 0; i < 8; i++)
				begin
					if (crc8_result[7])
					begin
						crc8_result = (crc8_result << 1) ^ polynomial8;
					end
					else 
					begin
						crc8_result = crc8_result << 1;
					end
				end 
        end
    endtask

	always @(negedge CSNeg_ipd)
	begin : CS_ASSERT
		//bus_cycle_state = OPCODE_BYTE;
		Address = 32'd0;
	end

	always @(posedge CSNeg_ipd)
	begin : CS_DEASSERT
		#1;
		opcode_byte = 8'h0;
		as_cnt = 0;
		quad_byte = 16'h0;
		crc8_result = 8'hFF;
		write_new = 1'b1;
		as_dc_cnt = 0;
		as_data_cnt = 0;
		data_cnt = 0;
	end

	always @(bus_cycle_state)
	begin
		if (bus_cycle_state == STAND_BY)
		begin
			if (
				Instruct == WRENB_0_0 ||
				Instruct == WRARG_C_1 ||
				Instruct == WRDYB_C_1 ||	
				Instruct == WRDYB_4_1 ||	
				Instruct == PRPPB_C_0 ||	
				Instruct == PRPPB_4_0 ||				
				Instruct == CLECC_0_0 ||
				Instruct == SRSTE_0_0 ||
				Instruct == SFRST_0_0 ||
				Instruct == DICHK_C_1 ||
				Instruct == ERO04_C_0 ||
				Instruct == ERO04_4_0 ||
				Instruct == ERO32_C_0 ||
				Instruct == ERO32_4_0 ||
				Instruct == ERO64_C_0 ||
				Instruct == ERO64_4_0 ||
				Instruct == ERCHP_0_0_60 ||
				Instruct == ERCHP_0_0_C7 ||
				Instruct == ERPPB_0_0 ||
				Instruct == WRPLB_0_0 ||
				Instruct == EVERS_C_0 ||
				Instruct == SEERC_C_0
			   )
			begin
				write = 1;
				#1;
				write = 0;
			end
		end
	end

/* 	always @(posedge SCK_ipd)
	begin : Buscycle_opcode
		case (bus_cycle_state)
			OPCODE_BYTE:
			begin
				if (QPI_IT)
				begin
					as_cnt = as_cnt + 1;

					if (!SDRDDR)
					begin
						if (as_cnt==1)
						begin
							opcode_byte[7:4] = {DQ3_in,DQ2_in,SO_in,SI_in};
						end
						else if (as_cnt==2)
						begin
							opcode_byte[3:0] = {DQ3_in,DQ2_in,SO_in,SI_in};

							CALC_CRC8(opcode_byte);

							set_instruct_value();

							ns_from_opcode();
							as_cnt = 0;
						end
					end
					else
					begin
						if (as_cnt==1)
						begin
							opcode_byte[7:4] = {DQ3_in,DQ2_in,SO_in,SI_in};
						end
					end
				end
				else
				begin
					as_cnt = as_cnt + 1;
					opcode_byte[8-as_cnt] = SI_in;

					if (as_cnt==8)
					begin
						set_instruct_value();

						CALC_CRC8(opcode_byte);
					end

					if (as_cnt==8 && Instruct != RDAY7_C_0 && Instruct != RDAY7_4_0)
					begin
						ns_from_opcode();
						as_cnt = 0;
					end
				end
			end
		endcase
	end */

	always @(posedge SCK_ipd)
	begin : Buscycle_opcode
		case (bus_cycle_state)
			OPCODE_BYTE:
			begin
				if (QPI_IT)
				begin
					as_cnt = as_cnt + 1;
					
					if (as_cnt==1)
					begin
						opcode_byte[7:4] = {DQ3_in,DQ2_in,SO_in,SI_in};	
					end
					else if(as_cnt==2)
					begin
						opcode_byte[3:0] = {DQ3_in,DQ2_in,SO_in,SI_in};
						CALC_CRC8(opcode_byte);
						set_instruct_value();

						if (!SDRDDR) 
						begin
						  as_cnt = 0;						
						  ns_from_opcode();   
						end
					end
				end
				else
				begin
					as_cnt = as_cnt + 1;
					opcode_byte[8-as_cnt] = SI_in;

					if (as_cnt==8)
					begin
						set_instruct_value();

						CALC_CRC8(opcode_byte);
					end

					if (as_cnt==8 && Instruct != RDAY7_C_0 && Instruct != RDAY7_4_0)
					begin
						ns_from_opcode();
						as_cnt = 0;
					end
				end
			end
		endcase
	end


/* 	always @(negedge SCK_ipd)
	begin : Buscycle_opcode_negedge
		case (bus_cycle_state)
			OPCODE_BYTE:
			begin
				if (SDRDDR)
				begin
					as_cnt = as_cnt + 1;
				end

				if (QPI_IT && SDRDDR && as_cnt==2)
				begin
					opcode_byte[3:0] = {DQ3_in,DQ2_in,SO_in,SI_in};

					set_instruct_value();

					CALC_CRC8(opcode_byte);

					ns_from_opcode();
					as_cnt = 0;
				end
				else if (!QPI_IT && (Instruct == RDAY7_C_0 || Instruct == RDAY7_4_0))
				begin
					ns_from_opcode();
					as_cnt = 0;
				end
			end
		endcase
	end */
	
	
	always @(negedge SCK_ipd)
	begin : Buscycle_opcode_negedge
		case (bus_cycle_state)
			OPCODE_BYTE:
			begin
				// if (SDRDDR)
				// begin
					// as_cnt = as_cnt + 1;
				// end

				if (QPI_IT && SDRDDR && as_cnt==2)
				begin
					//opcode_byte[3:0] = {DQ3_in,DQ2_in,SO_in,SI_in};

					//set_instruct_value();

					//CALC_CRC8(opcode_byte);

					ns_from_opcode();
					as_cnt = 0;
				end
				else if (!QPI_IT && (Instruct == RDAY7_C_0 || Instruct == RDAY7_4_0))
				begin
					ns_from_opcode();
					as_cnt = 0;
				end
			end
		endcase
	end

	always @(posedge SCK_ipd or negedge SCK_ipd)
	begin : Buscycle_crc_opcode
		case (bus_cycle_state)
			CRC_OPCODE_BYTES:
			begin
				if (QPI_IT && SDRDDR)
				begin
					as_cnt = as_cnt + 1;

					quad_byte = {DQ3_in,DQ2_in,SO_in,SI_in};

					if (quad_byte == ~crc8_result[(3-as_cnt)*4 - 1 -: 4])
					begin
						if (as_cnt == 1) crc_pass_cmd = 1;
						else			 crc_pass_cmd = crc_pass_cmd & 1;
					end
					else
					begin
						crc_pass_cmd = 0;
						INS1V[0] = 0;
					end

					if (as_cnt == 2)
					begin
						as_cnt = 0;
						crc8_result = 8'hFF;

						ns_from_crc_opcode();
					end
				end
				else if (QPI_IT && !SDRDDR)
				begin
					if (SCK_ipd)
					begin
						as_cnt = as_cnt + 1;

						quad_byte = {DQ3_in,DQ2_in,SO_in,SI_in};

						if (quad_byte == ~crc8_result[(3-as_cnt)*4 - 1 -: 4])
						begin
							if (as_cnt == 1) crc_pass_cmd = 1;
							else			 crc_pass_cmd = crc_pass_cmd & 1;
						end
						else
						begin
							crc_pass_cmd = 0;
							INS1V[0] = 0;
						end

						if (as_cnt == 2)
						begin
							as_cnt = 0;
							crc8_result = 8'hFF;

							ns_from_crc_opcode();
						end
					end
				end
				else if (!QPI_IT)
				begin
					if (SCK_ipd)
					begin
						as_cnt = as_cnt + 1;

						quad_byte[3-((as_cnt-1)%4)] = SI_in;

						if (quad_byte[3-((as_cnt-1)%4)] == ~crc8_result[8-as_cnt])
						begin
							if (as_cnt == 1) crc_pass_cmd = 1;
							else			 crc_pass_cmd = crc_pass_cmd & 1;
						end
						else
						begin
							crc_pass_cmd = 0;
							INS1V[0] = 0;
						end

						if (as_cnt == 8)
						begin
							as_cnt = 0;
							crc8_result = 8'hFF;

							ns_from_crc_opcode();
						end
					end
				end
			end
		endcase
	end

	always @(posedge SCK_ipd or negedge SCK_ipd)
	begin : Buscycle_address
		case (bus_cycle_state)
			ADDRESS_BYTES:
			begin
				if (
					(QPI_IT && SDRDDR) ||
					(!QPI_IT && (Instruct == RDAY7_C_0 || Instruct == RDAY7_4_0))
				   )
				begin
					as_cnt = as_cnt + 1;

					if (Instruct == RSFDP_C_0)
					begin
						Address[(7-as_cnt)*4 - 1 -: 4] = {DQ3_in,DQ2_in,SO_in,SI_in};

						if (as_cnt % 2 == 0) CALC_CRC8(Address[(7-as_cnt+1)*4 - 1 -: 8]);

						if (as_cnt == 6)
						begin
							ns_from_address();

							as_cnt = 0;
						end
					end
					else if (
							 Instruct == RDECC_4_0 || Instruct == RDAY7_4_0 || Instruct == PRPGE_4_1 ||
							 Instruct == ERO04_4_0 || Instruct == ERO32_4_0 || Instruct == ERO64_4_0 ||
							 Instruct == RDDYB_4_0 || Instruct == WRDYB_4_1 || Instruct == RDPPB_4_0 ||
							 Instruct == PRPPB_4_0
						    )
					begin
						Address[(9-as_cnt)*4 - 1 -: 4] = {DQ3_in,DQ2_in,SO_in,SI_in};

						if (as_cnt % 2 == 0) CALC_CRC8(Address[(10-as_cnt)*4 - 1 -: 8]);

						if (as_cnt == 8)
						begin
							ns_from_address();

							as_cnt = 0;
						end
					end
					else
					begin
						Address[((2*CFR2V[7])+7-as_cnt)*4 - 1 -: 4] = {DQ3_in,DQ2_in,SO_in,SI_in};

						if (as_cnt % 2 == 0) CALC_CRC8(Address[(2*CFR2V[7]+7-as_cnt+1)*4 - 1 -: 8]);

						if (as_cnt == (6 + 2*CFR2V[7]))
						begin
							ns_from_address();

							as_cnt = 0;
						end
					end
				end
				else if (
						 (QPI_IT && !SDRDDR) ||
						 (!QPI_IT && (Instruct == RDAY5_C_0 || Instruct == RDAY5_4_0)) ||
						 (!QPI_IT && (Instruct == PRPG3_C_1 || Instruct == PRPG3_4_1))
						)
				begin
					if (SCK_ipd)
					begin
						as_cnt = as_cnt + 1;

						if (Instruct == RSFDP_C_0)
						begin
							Address[(7-as_cnt)*4 - 1 -: 4] = {DQ3_in,DQ2_in,SO_in,SI_in};

							if (as_cnt % 2 == 0) CALC_CRC8(Address[(7-as_cnt+1)*4 - 1 -: 8]);

							if (as_cnt == 6)
							begin
								ns_from_address();

								as_cnt = 0;
							end	
						end
						else if (
							 Instruct == RDECC_4_0 || Instruct == RDAY5_4_0 || Instruct == PRPGE_4_1 ||
							 Instruct == ERO04_4_0 || Instruct == ERO32_4_0 || Instruct == ERO64_4_0 ||
							 Instruct == RDDYB_4_0 || Instruct == WRDYB_4_1 || Instruct == RDPPB_4_0 ||
							 Instruct == PRPPB_4_0
						    )
						begin
							Address[(9-as_cnt)*4 - 1 -: 4] = {DQ3_in,DQ2_in,SO_in,SI_in};

							if (as_cnt % 2 == 0) CALC_CRC8(Address[(9-as_cnt+1)*4 - 1 -: 8]);

							if (as_cnt == 8)
							begin
								ns_from_address();

								as_cnt = 0;
							end
						end
						else
						begin
							Address[((2*CFR2V[7])+7-as_cnt)*4 - 1 -: 4] = {DQ3_in,DQ2_in,SO_in,SI_in};

							if (as_cnt % 2 == 0) CALC_CRC8(Address[((2*CFR2V[7])+7-as_cnt+1)*4 - 1 -: 8]);

							if (as_cnt == (6 + 2*CFR2V[7]))
							begin
								ns_from_address();

								as_cnt = 0;
							end
						end
					end
				end
				else
				begin
					if (SCK_ipd)
					begin
						as_cnt = as_cnt + 1;

						if (Instruct == RSFDP_C_0)
						begin
							Address[24 - as_cnt] = SI_in;

							if (as_cnt % 8 == 0) CALC_CRC8(Address[(32-as_cnt-1) -: 8]);

							if (as_cnt == 24)
							begin
								ns_from_address();

								as_cnt = 0;
							end
						end
						else if (
								 Instruct == RDECC_4_0 || Instruct == RDAY1_4_0 || Instruct == RDAY2_4_0 ||
								 Instruct == PRPGE_4_1 || Instruct == ERO04_4_0 || Instruct == ERO32_4_0 ||
								 Instruct == ERO64_4_0 || Instruct == RDDYB_4_0 || Instruct == WRDYB_4_1 ||
								 Instruct == RDPPB_4_0 || Instruct == PRPPB_4_0
								)
						begin
							Address[32 - as_cnt] = SI_in;

							if (as_cnt % 8 == 0) CALC_CRC8(Address[(40-as_cnt-1) -: 8]);

							if (as_cnt == 32)
							begin
								ns_from_address();

								as_cnt = 0;
							end
						end
						else
						begin
							Address[8*(3+CFR2V[7]) - as_cnt] = SI_in;

							if (as_cnt % 8 == 0) CALC_CRC8(Address[(8*(4+CFR2V[7])-as_cnt-1) -: 8]);

							if (as_cnt == 8*(3+CFR2V[7]))
							begin
								ns_from_address();

								as_cnt = 0;
							end
						end
					end
				end
			end
		endcase
	end

	always @(posedge SCK_ipd or negedge SCK_ipd)
	begin : Buscycle_crc_address
		case (bus_cycle_state)
			CRC_ADDRESS_BYTES:
			begin
				if (
					(QPI_IT && SDRDDR) ||
					(!QPI_IT && (Instruct == RDAY7_C_0 || Instruct == RDAY7_4_0))
				   )
				begin
					as_cnt = as_cnt + 1;

					quad_byte = {DQ3_in,DQ2_in,SO_in,SI_in};

					if (quad_byte == ~crc8_result[(3-as_cnt)*4 - 1 -: 4])
					begin
						if (as_cnt ==1 ) crc_pass_cmd = 1;
						else			 crc_pass_cmd = crc_pass_cmd & 1;
					end
					else
					begin
						crc_pass_cmd = 0;
						INS1V[0] = 0;
					end

					if (as_cnt == 2)
					begin
						as_cnt = 0;
						crc8_result = 8'hFF;

						ns_from_crc_address();
					end
				end
				else if (
						 (QPI_IT && !SDRDDR) ||
						 (!QPI_IT && (Instruct == RDAY5_C_0 || Instruct == RDAY5_4_0))
						)
				begin
					if (SCK_ipd)
					begin
						as_cnt = as_cnt + 1;

						quad_byte = {DQ3_in,DQ2_in,SO_in,SI_in};

						if (quad_byte == ~crc8_result[(3-as_cnt)*4 - 1 -: 4])
						begin
							if (as_cnt == 1) crc_pass_cmd = 1;
							else			 crc_pass_cmd = crc_pass_cmd & 1;
						end
						else
						begin
							crc_pass_cmd = 0;
							INS1V[0] = 0;
						end

						if (as_cnt == 2)
						begin
							as_cnt = 0;
							crc8_result = 8'hFF;

							ns_from_crc_address();
						end
					end
				end
				else if (!QPI_IT)
				begin
					if (SCK_ipd)
					begin
						as_cnt = as_cnt + 1;

						quad_byte[3-((as_cnt-1)%4)] = SI_in;

						if (quad_byte[3-((as_cnt-1)%4)] == ~crc8_result[8-as_cnt])
						begin
							if (as_cnt) crc_pass_cmd = 1;
							else		crc_pass_cmd = crc_pass_cmd & 1;
						end
						else
						begin
							crc_pass_cmd = 0;
							INS1V[0] = 0;
						end

						if (as_cnt == 8)
						begin
							as_cnt = 0;
							crc8_result = 8'hFF;

							ns_from_crc_address();
						end
					end
				end
			end
		endcase
	end

	always @(posedge SCK_ipd or negedge SCK_ipd)
	begin : Buscycle_data_in
		case (bus_cycle_state)
			DATA_IN_BYTES:
			begin
				if (QPI_IT && SDRDDR)
				begin
					as_cnt = as_cnt + 1;

					if (ITCRCE)
					begin
						if ((((data_cnt+1)/2)) % (sgm_size) == 0 && data_cnt >= 8*2 && as_cnt >= 8*2)
						begin
							#1;
							bus_cycle_state = CRC_DATA_IN_BYTES;
							as_cnt = 0;
						end
					end

					quad_data_in[data_cnt] = {DQ3_in,DQ2_in,SO_in,SI_in};

					if (as_cnt % 2 == 0) CALC_CRC8({quad_data_in[data_cnt-1][3:0],quad_data_in[data_cnt][3:0]});

					data_cnt = data_cnt + 1;
				end
				else if ((QPI_IT && !SDRDDR) ||
						 (!QPI_IT && (Instruct==PRPG2_C_1 || Instruct==PRPG2_4_1 || Instruct==PRPG3_C_1 || Instruct==PRPG3_4_1)))
				begin
					if (SCK_ipd)
					begin
						as_cnt = as_cnt + 1;

						if (ITCRCE)
						begin
							if ((data_cnt+1)/2 % (sgm_size) == 0 && data_cnt >= 8*2 && as_cnt >= 8*2)
							begin
								#1;
								bus_cycle_state = CRC_DATA_IN_BYTES;
								as_cnt = 0;
							end
						end

						quad_data_in[data_cnt] = {DQ3_in,DQ2_in,SO_in,SI_in};

						if (as_cnt % 2 == 0) CALC_CRC8({quad_data_in[data_cnt-1][3:0],quad_data_in[data_cnt][3:0]});

						data_cnt = data_cnt + 1;
					end
				end
				else
				begin
					if (SCK_ipd)
					begin
						as_cnt = as_cnt + 1;

						if (ITCRCE)
						begin
							if ((data_cnt+1)/8 % (sgm_size) == 0 && data_cnt >= 8*8 && as_cnt >= 8*8)
							begin
								#1;
								bus_cycle_state = CRC_DATA_IN_BYTES;
								as_cnt = 0;
							end
						end

						Data_in[(data_cnt/8)*8 + (7 - (data_cnt%8))] = SI_in;

						if (as_cnt % 8 ==0) CALC_CRC8(Data_in[data_cnt -: 8]);

						data_cnt = data_cnt + 1;
					end
				end
				
				if (Instruct == WRREG_0_1) wrreg_bytes = QPI_IT ? data_cnt/2 : data_cnt/8;
			end
		endcase
	end

	always @(posedge SCK_ipd or negedge SCK_ipd)
	begin : Buscycle_crc_data_in
		case (bus_cycle_state)
			CRC_DATA_IN_BYTES:
			begin
				if (QPI_IT && SDRDDR)
				begin
					as_cnt = as_cnt + 1;

					quad_byte = {DQ3_in,DQ2_in,SO_in,SI_in};

					if (quad_byte == ~crc8_result[(3-as_cnt)*4 - 1 -: 4])
					begin
						if (as_cnt == 1) crc_pass_cmd = 1;
						else			 crc_pass_cmd = crc_pass_cmd & 1;
					end
					else
					begin
						crc_pass_cmd = 0;
						INS1V[0] = 0;
					end

					if (as_cnt == 2)
					begin
						as_cnt = 0;
						crc8_result = 8'hFF;

						#1;
						bus_cycle_state = DATA_IN_BYTES;
					end
				end
				else if ((QPI_IT && !SDRDDR) ||
						 (!QPI_IT && (Instruct==PRPG2_C_1 || Instruct==PRPG2_4_1 || Instruct==PRPG3_C_1 || Instruct==PRPG3_4_1)))
				begin
					if (SCK_ipd)
					begin
						as_cnt = as_cnt + 1;

						quad_byte = {DQ3_in,DQ2_in,SO_in,SI_in};

						if (quad_byte == ~crc8_result[(3-as_cnt)*4 - 1 -: 4])
						begin
							if (as_cnt == 1) crc_pass_cmd = 1;
							else			 crc_pass_cmd = crc_pass_cmd & 1;
						end
						else
						begin
							crc_pass_cmd = 0;
							INS1V[0] = 0;
						end

						if (as_cnt == 2)
						begin
							as_cnt = 0;
							crc8_result = 8'hFF;

							#1;
							bus_cycle_state = DATA_IN_BYTES;
						end
					end
				end
				else if (!QPI_IT)
				begin
					if (SCK_ipd)
					begin
						as_cnt = as_cnt + 1;

						quad_byte[3-((as_cnt-1)%4)] = SI_in;

						if (quad_byte[3-((as_cnt-1)%4)] == ~crc8_result[8-as_cnt])
						begin
							if (as_cnt == 1) crc_pass_cmd = 1;
							else			 crc_pass_cmd = crc_pass_cmd & 1;
						end
						else
						begin
							crc_pass_cmd = 0;
							INS1V[0] = 0;
						end

						if (as_cnt == 8)
						begin
							as_cnt = 0;
							crc8_result = 8'hFF;

							#1;
							bus_cycle_state = DATA_IN_BYTES;
						end
					end
				end
			end
		endcase
	end

	always @(bus_cycle_state)
	begin : dc_lv //dummy cycle latency value
		if (bus_cycle_state==DUMMY_BYTES)
		begin
			if		(Instruct == RDIDN_0_0 && !QPI_IT && !ITCRCE) as_dc_cnt = 0;			
			else if (Instruct == RDIDN_0_0) as_dc_cnt = 4;
			else if (Instruct == RDQID_0_0) as_dc_cnt = 4;
			else if (Instruct == RDUID_0_0) as_dc_cnt = 32;			
			else if (Instruct == RSFDP_C_0) as_dc_cnt = 8;			 						
			else if (Instruct == RDSR1_0_0) as_dc_cnt = 4;			
			else if (Instruct == RDSR2_0_0) as_dc_cnt = 4;
			else if (Instruct == RDPLB_0_0 ) as_dc_cnt = 4;
			else if (Instruct == RDDYB_4_0 ) as_dc_cnt = 4;
			else if (Instruct == RDDYB_C_0 ) as_dc_cnt = 4;
			else if (
					 Instruct == RDECC_C_0 ||
					 Instruct == RDECC_4_0 ||
					 Instruct == RDSSR_C_0 ||
					 Instruct == RDAY1_C_0 ||
					 Instruct == RDAY1_4_0 ||
					 Instruct == RDAY2_C_0 ||
					 Instruct == RDAY2_4_0 ||
					 Instruct == RDAY4_C_0 ||
					 Instruct == RDAY4_4_0 ||
					 Instruct == RDAY5_C_0 ||
					 Instruct == RDAY5_4_0 ||
					 Instruct == RDAY7_C_0 ||
					 Instruct == RDAY7_4_0
					)
			begin
				as_dc_cnt = Latency_code;
			end

			else if (Instruct == RDARG_C_0)
			begin
				if (Address[23:16] == 8'h80)
				begin
					if   (QPI_IT && SDRDDR) as_dc_cnt = 5;
					else				    as_dc_cnt = 4;
				end
				else
				begin
					if   (QPI_IT && SDRDDR) as_dc_cnt = Latency_code + 1;
					else				    as_dc_cnt = Latency_code;
				end
			end
			
			else if (Instruct == RDPPB_4_0 || Instruct == RDPPB_C_0)
			begin
				if   (QPI_IT && SDRDDR) as_dc_cnt = Latency_code + 1;
				else				    as_dc_cnt = Latency_code;
			end

			if (QPI_IT && SDRDDR)
			begin
				if (
					Instruct == RDIDN_0_0 ||
					Instruct == RDQID_0_0 ||
					Instruct == RDUID_0_0 ||
					Instruct == RSFDP_C_0 ||
					Instruct == RDSSR_C_0 ||
					Instruct == RDSR1_0_0 ||
					Instruct == RDPLB_0_0 ||
					Instruct == RDDYB_4_0 ||
					Instruct == RDDYB_C_0 ||
					Instruct == RDSR2_0_0 ||
					Instruct == RDECC_C_0 ||
					Instruct == RDECC_4_0 ||
					Instruct == RDAY7_C_0 ||
					Instruct == RDAY7_4_0
				   )
				begin
					as_dc_cnt = as_dc_cnt + 1;
				end
			end
			else if (!QPI_IT && (Instruct == RDAY7_C_0 || Instruct == RDAY7_4_0))
			begin
				as_dc_cnt = as_dc_cnt + 1;
			end

			if (
				(QPI_IT && SDRDDR && ITCRCE) ||
				(!QPI_IT && Instruct == RDAY7_C_0 && ITCRCE) ||
				(!QPI_IT && Instruct == RDAY7_4_0 && ITCRCE)
			   )
			begin
				if	 (as_dc_cnt >= 1) as_dc_cnt = as_dc_cnt - 1;
				else				  as_dc_cnt = 0;
			end
			else if (
					 (QPI_IT && !SDRDDR && ITCRCE) ||
					 (!QPI_IT && Instruct == RDAY5_C_0 && ITCRCE) ||
					 (!QPI_IT && Instruct == RDAY5_4_0 && ITCRCE)
					)
			begin
				if   (as_dc_cnt >= 2) as_dc_cnt = as_dc_cnt - 2;
				else				  as_dc_cnt = 0;
			end
			else if (!QPI_IT && ITCRCE)
			begin
				if	 (as_dc_cnt >= 8) as_dc_cnt = as_dc_cnt - 8;
				else				  as_dc_cnt = 0;
			end

			if (as_dc_cnt == 0)
			begin
				bus_cycle_state = DATA_OUT_BYTES;
			end
		end
	end

	always @(posedge SCK_ipd or negedge SCK_ipd)
	begin : Buscycle_dummy_cycle
		case(bus_cycle_state)
			DUMMY_BYTES:
			begin
				if (SCK_ipd)
				begin
					as_cnt = as_cnt + 1;

					if (as_cnt == as_dc_cnt)
					begin
						#1;
						bus_cycle_state = DATA_OUT_BYTES;

						as_cnt = 0;
					end
					
/* 					if ((SDRDDR && 
					    (Instruct == RDDYB_C_0 || 
						Instruct == RDDYB_4_0 || 
						Instruct == RDPPB_C_0 || 
						Instruct == RDPPB_4_0 || 
						Instruct == RDPLB_0_0 || 
						Instruct == RDARG_C_0 || 
						Instruct == RDQID_0_0 || 
						Instruct == RSFDP_3_0 || 
						Instruct == RDIDN_0_0)) 
						&& as_cnt == (as_dc_cnt-1))
						begin
							#1 bus_cycle_state = DATA_OUT_BYTES;

							as_cnt = 0;
						end */	
				end
				else
				begin
					//for some commands need to adjust half cycle moving
					//from one clock edge to another clock edge
					
					if (
						Instruct == RDIDN_0_0 ||
						Instruct == RSFDP_C_0 ||
						Instruct == RDSSR_C_0 ||
						Instruct == RDARG_C_0 ||
						Instruct == RDDYB_C_0 ||
						Instruct == RDDYB_4_0 ||
						Instruct == RDPPB_C_0 ||
						Instruct == RDPPB_4_0 ||
						Instruct == RDECC_C_0 ||
						Instruct == RDECC_4_0 ||
						Instruct == RDAY7_C_0 ||
						Instruct == RDAY7_4_0 ||
						(Instruct == RDUID_0_0 && SDRDDR) ||
						(Instruct == RDQID_0_0 && SDRDDR) ||
						(Instruct == RDSR1_0_0 && SDRDDR) ||
						(Instruct == RDPLB_0_0 && SDRDDR) ||
						(Instruct == RDSR2_0_0 && SDRDDR)
					   )
					begin
						if ((SDRDDR || Instruct == RDAY7_C_0 || Instruct == RDAY7_4_0 || Instruct == RDDYB_C_0 || Instruct == RDDYB_4_0) && as_cnt == (as_dc_cnt-1))
						begin
							#1 bus_cycle_state = DATA_OUT_BYTES;

							as_cnt = 0;
						end
					end
				end
			end
		endcase
	end

	always @(bus_cycle_state)
	begin
		if (bus_cycle_state == DATA_OUT_BYTES)
		begin
			if 		(Instruct == RDIDN_0_0)	as_data_cnt = 0; //keeps reading as long as there is clock. Wraps back to 1st address at end boundary
			else if (Instruct == RDQID_0_0)	as_data_cnt = 0; //keeps reading as long as there is clock. Wraps back to 1st address at end boundary
			else if (Instruct == RSFDP_C_0) as_data_cnt = 0; //keeps reading as long as there is clock. Wraps back to 1st address at end boundary
			else if (Instruct == RDARG_C_0) as_data_cnt = (QPI_IT) ? (1+ITCRCE)*2 : (1+ITCRCE)*8;
			else if (Instruct == RDUID_0_0) as_data_cnt = 0; //keeps reading as long as there is clock. Wraps back to 1st address at end boundary
			else if (Instruct == RDSSR_C_0) as_data_cnt = 0; //keeps reading as long as there is clock. Wraps back to 1st address at end boundary 
			else if (Instruct == RDSR1_0_0) as_data_cnt = (QPI_IT) ? (1+ITCRCE)*2 : (1+ITCRCE)*8;
			else if (Instruct == RDSR2_0_0) as_data_cnt = (QPI_IT) ? (1+ITCRCE)*2 : (1+ITCRCE)*8;
			else if (Instruct == RDAY7_C_0) as_data_cnt = 0; //keeps reading as long as there is clock.
			else if (Instruct == RDAY7_4_0) as_data_cnt = 0; //keeps reading as long as there is clock.
			else if (Instruct == RDAY4_C_0) as_data_cnt = 0; //keeps reading as long as there is clock.
			else if (Instruct == RDAY4_4_0) as_data_cnt = 0; //keeps reading as long as there is clock.
			else if (Instruct == RDAY5_C_0) as_data_cnt = 0; //keeps reading as long as there is clock.
			else if (Instruct == RDAY5_4_0) as_data_cnt = 0; //keeps reading as long as there is clock.
			else if (Instruct == RDAY1_C_0) as_data_cnt = 0; //keeps reading as long as there is clock.
			else if (Instruct == RDAY1_4_0) as_data_cnt = 0; //keeps reading as long as there is clock.
			else if (Instruct == RDAY2_C_0) as_data_cnt = 0; //keeps reading as long as there is clock.
			else if (Instruct == RDAY2_4_0) as_data_cnt = 0; //keeps reading as long as there is clock.
		end
	end

	always @(posedge SCK_ipd or negedge SCK_ipd)
	begin : Buscycle_data_out
		case(bus_cycle_state)
			DATA_OUT_BYTES:
			begin
				if (
					(QPI_IT && SDRDDR) ||
					(!QPI_IT && Instruct == RDAY7_C_0) ||
					(!QPI_IT && Instruct == RDAY7_4_0)
				   )
				begin
					as_cnt = as_cnt + 1;

					if (as_cnt <= as_data_cnt || as_data_cnt == 0)
					begin
						read_out = 1;
						#1 read_out = 0;
					end
				end
				else if (
						 (QPI_IT && !SDRDDR) ||
						 (!QPI_IT && Instruct == RDAY4_C_0) ||
						 (!QPI_IT && Instruct == RDAY4_4_0) ||
						 (!QPI_IT && Instruct == RDAY5_C_0) ||
						 (!QPI_IT && Instruct == RDAY5_4_0)
						)
				begin
					if (!SCK_ipd)	//negedge
					begin
						as_cnt = as_cnt + 1;

						if (as_cnt <= as_data_cnt || as_data_cnt == 0)
						begin
							read_out = 1;
							#1 read_out = 0;
						end
					end
				end
				else
				begin
					if (!SCK_ipd)	//negedge
					begin
						as_cnt = as_cnt + 1;

						if (as_cnt <= as_data_cnt || as_data_cnt == 0)
						begin
							read_out = 1;
							#1 read_out = 0;
						end
					end
				end
			end
		endcase
	end

	task set_instruct_value;
	begin
		#1;

		if 		(opcode_byte == 8'h06) Instruct = WRENB_0_0;
		else if (opcode_byte == 8'h9F) Instruct = RDIDN_0_0;
		else if (opcode_byte == 8'h9E) Instruct = RDIDN_0_0;
		else if (opcode_byte == 8'hAF) Instruct = RDQID_0_0;
		else if (opcode_byte == 8'h5A) Instruct = RSFDP_C_0; //RSFDP_3_0
		else if (opcode_byte == 8'h4C) Instruct = RDUID_0_0;
		else if (opcode_byte == 8'h65) Instruct = RDARG_C_0;
		else if (opcode_byte == 8'hFA) Instruct = RDDYB_C_0;
		else if (opcode_byte == 8'hE0) Instruct = RDDYB_4_0;
		else if (opcode_byte == 8'hFC) Instruct = RDPPB_C_0;
		else if (opcode_byte == 8'hE2) Instruct = RDPPB_4_0;		
		else if (opcode_byte == 8'h71) Instruct = WRARG_C_1;
		else if (opcode_byte == 8'hFB) Instruct = WRDYB_C_1;
		else if (opcode_byte == 8'hE1) Instruct = WRDYB_4_1;
		else if (opcode_byte == 8'hFE) Instruct = PRPPB_C_0;
		else if (opcode_byte == 8'hE3) Instruct = PRPPB_4_0;
		else if (opcode_byte == 8'hB7) Instruct = EN4BA_0_0;
		else if (opcode_byte == 8'hB8) Instruct = EX4BA_0_0;
		else if (opcode_byte == 8'h42) Instruct = PRSSR_C_1;
		else if (opcode_byte == 8'h4B) Instruct = RDSSR_C_0;
		else if (opcode_byte == 8'h05) Instruct = RDSR1_0_0;
		else if (opcode_byte == 8'h07) Instruct = RDSR2_0_0;
		else if (opcode_byte == 8'hA7) Instruct = RDPLB_0_0;
		else if (opcode_byte == 8'h04) Instruct = WRDIS_0_0;
		else if (opcode_byte == 8'h50) Instruct = WRENV_0_0;
		else if (opcode_byte == 8'h30) Instruct = CLPEF_0_0;
		else if (opcode_byte == 8'h01) Instruct = WRREG_0_1;
		else if (opcode_byte == 8'hE8) Instruct = PGPWD_0_1;
		else if (opcode_byte == 8'h2F) Instruct = PRASP_0_1;		
		else if (opcode_byte == 8'hE9) Instruct = PWDUL_0_1;
		else if (opcode_byte == 8'hA6) Instruct = WRPLB_0_0;
		else if (opcode_byte == 8'h18) Instruct = RDECC_C_0;
		else if (opcode_byte == 8'h19) Instruct = RDECC_4_0;
		else if (opcode_byte == 8'h1B) Instruct = CLECC_0_0;
		else if (opcode_byte == 8'hB9) Instruct = ENDPD_0_0;
		else if (opcode_byte == 8'h66) Instruct = SRSTE_0_0;
		else if (opcode_byte == 8'h99) Instruct = SFRST_0_0;
		else if (opcode_byte == 8'hED) Instruct = RDAY7_C_0;
		else if (opcode_byte == 8'hEE) Instruct = RDAY7_4_0;
		else if (opcode_byte == 8'hEB) Instruct = RDAY5_C_0;
		else if (opcode_byte == 8'hEC) Instruct = RDAY5_4_0;
		else if (opcode_byte == 8'h03) Instruct = RDAY1_C_0;
		else if (opcode_byte == 8'h13) Instruct = RDAY1_4_0;
		else if (opcode_byte == 8'h0B) Instruct = RDAY2_C_0;
		else if (opcode_byte == 8'h0C) Instruct = RDAY2_4_0;
		else if (opcode_byte == 8'h02) Instruct = PRPGE_C_1;
		else if (opcode_byte == 8'h12) Instruct = PRPGE_4_1;
		else if (opcode_byte == 8'h5B) Instruct = DICHK_C_1;
		else if (opcode_byte == 8'h20) Instruct = ERO04_C_0;
		else if (opcode_byte == 8'h21) Instruct = ERO04_4_0;
		else if (opcode_byte == 8'h52) Instruct = ERO32_C_0;
		else if (opcode_byte == 8'h53) Instruct = ERO32_4_0;
		else if (opcode_byte == 8'hD8) Instruct = ERO64_C_0;
		else if (opcode_byte == 8'hDC) Instruct = ERO64_4_0;
		else if (opcode_byte == 8'h60) Instruct = ERCHP_0_0_60;
		else if (opcode_byte == 8'hC7) Instruct = ERCHP_0_0_C7;
		else if (opcode_byte == 8'hE4) Instruct = ERPPB_0_0;
		else if (opcode_byte == 8'hD0) Instruct = EVERS_C_0;
		else if (opcode_byte == 8'h5D) Instruct = SEERC_C_0;
		else if (opcode_byte == 8'h75) Instruct = SPEPD_0_0;
		else if (opcode_byte == 8'h7A) Instruct = RSEPD_0_0;
		else if (opcode_byte == 8'h6B) Instruct = RDAY4_C_0;
		else if (opcode_byte == 8'h6C) Instruct = RDAY4_4_0;
		else if (opcode_byte == 8'h32) Instruct = PRPG2_C_1;
		else if (opcode_byte == 8'h34) Instruct = PRPG2_4_1;
		else if (opcode_byte == 8'h38) Instruct = PRPG3_C_1;
		else if (opcode_byte == 8'h3E) Instruct = PRPG3_4_1;

		if (
			Instruct == RDSSR_C_0 ||
			Instruct == RDECC_C_0 ||
			Instruct == RDECC_4_0 ||
			Instruct == RDAY7_C_0 ||
			Instruct == RDAY7_4_0 ||
			Instruct == RDAY5_C_0 ||
			Instruct == RDAY5_4_0 ||
			Instruct == RDAY1_C_0 ||
			Instruct == RDAY1_4_0 ||
			Instruct == RDAY2_C_0 ||
			Instruct == RDAY2_4_0 ||
			Instruct == RDAY4_C_0 ||
			Instruct == RDAY4_4_0 ||
            Instruct == RDPPB_4_0 ||
			Instruct == RDPPB_C_0 ||
			(Instruct == RDARG_C_0 && Address[23:0]==8'h00)
		)
		begin
			if (
				QPI_IT ||
				(Instruct == RDAY5_C_0 || Instruct == RDAY5_4_0) ||
				(Instruct == RDAY7_C_0 || Instruct == RDAY7_4_0)
			   )
			begin
				case (CFR2V[3:0])
					4'b0000 : Latency_code = 5;		// 0h
					4'b0001 : Latency_code = 6;		// 1h
					4'b0010 : Latency_code = 8;		// 2h
					4'b0011 : Latency_code = 10;	// 3h
					4'b0100 : Latency_code = 12;	// 5h
					4'b0101 : Latency_code = 14;	// 5h
					4'b0110 : Latency_code = 16;	// 6h
					4'b0111 : Latency_code = 18;	// 7h
					4'b1000 : Latency_code = 20;	// 8h
					4'b1001 : Latency_code = 22;	// 9h
					4'b1010 : Latency_code = 23;	// Ah
					4'b1011 : Latency_code = 24;	// Bh
					4'b1100 : Latency_code = 25;	// Ch
					4'b1101 : Latency_code = 26;	// Dh
					4'b1110 : Latency_code = 27;	// Eh
					4'b1111 : Latency_code = 28;	// Fh
				endcase
			end
			else
			begin
				Latency_code = CFR2V[3:0];
			end

			if (
				Instruct == RDAY4_C_0 ||
				Instruct == RDAY4_4_0 ||
				Instruct == RDAY5_C_0 ||
				Instruct == RDAY5_4_0 ||
				Instruct == RDAY7_C_0 ||
				Instruct == RDAY7_4_0
			   )
			begin
				DATA_STROBE = 1;
			end
		end
	end
	endtask
	
	task ns_from_opcode;
	begin
		#1;

		if (ITCRCE)
		begin
			if (
				Instruct == WRARG_C_1 ||
				Instruct == WRDYB_C_1 ||				
				Instruct == WRDYB_4_1 ||
				Instruct == PRPPB_C_0 ||				
				Instruct == PRPPB_4_0 ||				
				Instruct == RDARG_C_0 ||
				Instruct == RDDYB_C_0 ||
				Instruct == RDDYB_4_0 ||
				Instruct == RDPPB_C_0 ||
				Instruct == RDPPB_4_0 ||
				Instruct == RSFDP_C_0 ||
				Instruct == PRSSR_C_1 ||
				Instruct == RDSSR_C_0 ||
				Instruct == RDECC_C_0 ||
				Instruct == RDECC_4_0 ||
				Instruct == RDAY4_C_0 ||
				Instruct == RDAY4_4_0 ||
				Instruct == RDAY7_C_0 ||
				Instruct == RDAY7_4_0 ||
				Instruct == RDAY5_C_0 ||
				Instruct == RDAY5_4_0 ||
				Instruct == RDAY1_C_0 ||
				Instruct == RDAY1_4_0 ||
				Instruct == RDAY2_C_0 ||
				Instruct == RDAY2_4_0 ||
				Instruct == PRPGE_C_1 ||
				Instruct == PRPGE_4_1 ||
				Instruct == PRPG2_C_1 ||
				Instruct == PRPG2_4_1 ||
				Instruct == PRPG3_C_1 ||
				Instruct == PRPG3_4_1 ||
				Instruct == ERO04_C_0 ||
				Instruct == ERO04_4_0 ||
				Instruct == ERO32_C_0 ||
				Instruct == ERO32_4_0 ||
				Instruct == ERO64_C_0 ||
				Instruct == ERO64_4_0 ||
				Instruct == EVERS_C_0 ||
				Instruct == SEERC_C_0
			)
			begin
				bus_cycle_state = ADDRESS_BYTES;
			end
			else if (
				Instruct == EN4BA_0_0 ||
				Instruct == EX4BA_0_0 ||
				Instruct == WRENB_0_0 ||
				Instruct == WRDIS_0_0 ||
				Instruct == WRENV_0_0 ||
				Instruct == RDIDN_0_0 ||
				Instruct == RDQID_0_0 ||
				Instruct == RDUID_0_0 ||
				Instruct == RDSR1_0_0 ||
				Instruct == RDPLB_0_0 ||
				Instruct == RDSR2_0_0 ||
				Instruct == CLPEF_0_0 ||
				Instruct == WRREG_0_1 ||
				Instruct == PGPWD_0_1 ||
				Instruct == PRASP_0_1 ||				
				Instruct == PWDUL_0_1 ||
				Instruct == CLECC_0_0 ||
				Instruct == ENDPD_0_0 ||
				Instruct == SRSTE_0_0 ||
				Instruct == SFRST_0_0 ||
				Instruct == DICHK_C_1 ||
				Instruct == ERCHP_0_0_60 ||
				Instruct == ERPPB_0_0 ||	
				Instruct == WRPLB_0_0 ||				
				Instruct == ERCHP_0_0_C7
			)
			begin
				bus_cycle_state = CRC_OPCODE_BYTES;
			end
		end
		else if (
			Instruct == WRREG_0_1 ||
			Instruct == PGPWD_0_1 ||
			Instruct == PRASP_0_1 ||
			Instruct == PWDUL_0_1 ||
			Instruct == DICHK_C_1
		)
		begin
			bus_cycle_state = DATA_IN_BYTES;
		end
		else if (
			Instruct == WRENB_0_0 ||
			Instruct == WRDIS_0_0 ||
			Instruct == WRENV_0_0 ||
			Instruct == WRDIS_0_0 ||
			Instruct == CLPEF_0_0 ||
			Instruct == EN4BA_0_0 ||
			Instruct == EX4BA_0_0 ||
			Instruct == CLECC_0_0 ||
			Instruct == SRSTE_0_0 ||
			Instruct == SFRST_0_0 ||
			Instruct == CLPEF_0_0 ||
			Instruct == ERCHP_0_0_60 ||
			Instruct == ERPPB_0_0 ||		
			Instruct == WRPLB_0_0 ||			
			Instruct == ERCHP_0_0_C7
		)
		begin
			bus_cycle_state = DATA_OUT_BYTES;
		end
		else if (
			Instruct == RDIDN_0_0 ||
			Instruct == RDQID_0_0 ||
			Instruct == RDUID_0_0 ||
			Instruct == RDSR1_0_0 ||
			Instruct == RDPLB_0_0 ||
			Instruct == RDSR2_0_0 ||
			Instruct == ENDPD_0_0 ||
			Instruct == SRSTE_0_0 ||
			Instruct == SFRST_0_0
		)
		begin
			bus_cycle_state = DUMMY_BYTES;
		end
		else if (
			Instruct == RSFDP_C_0 ||
			Instruct == RDARG_C_0 ||
			Instruct == RDDYB_C_0 ||
			Instruct == RDDYB_4_0 ||
			Instruct == RDPPB_C_0 ||
			Instruct == RDPPB_4_0 ||
			Instruct == WRARG_C_1 ||
			Instruct == WRDYB_C_1 ||
			Instruct == WRDYB_4_1 ||
			Instruct == PRPPB_C_0 ||
			Instruct == PRPPB_4_0 ||
			Instruct == RDECC_C_0 ||
			Instruct == RDECC_4_0 ||
			Instruct == DICHK_C_1 ||
			Instruct == RDAY5_C_0 ||
			Instruct == RDAY5_4_0 ||
			Instruct == RDAY7_C_0 ||
			Instruct == RDAY7_4_0 ||
			Instruct == PRPGE_C_1 ||
			Instruct == PRPGE_4_1 ||
			Instruct == ERO04_C_0 ||
			Instruct == ERO04_4_0 ||
			Instruct == ERO32_C_0 ||
			Instruct == ERO32_4_0 ||
			Instruct == ERO64_C_0 ||
			Instruct == ERO64_4_0 ||
			Instruct == EVERS_C_0 ||
			Instruct == SEERC_C_0 ||
			Instruct == PRSSR_C_1 ||
			Instruct == RDSSR_C_0 ||
			Instruct == RDAY1_C_0 ||
			Instruct == RDAY1_4_0 ||
			Instruct == RDAY2_C_0 ||
			Instruct == RDAY2_4_0 ||
			Instruct == RDAY7_C_0 ||
			Instruct == RDAY7_4_0 ||
			Instruct == RDAY5_C_0 ||
			Instruct == RDAY5_4_0 ||
			Instruct == RDAY1_C_0 ||
			Instruct == RDAY1_4_0 ||
			Instruct == RDAY2_C_0 ||
			Instruct == RDAY2_4_0 ||
			Instruct == DICHK_C_1 ||
			Instruct == ERO04_C_0 ||
			Instruct == ERO04_4_0 ||
			Instruct == ERO32_C_0 ||
			Instruct == ERO32_4_0 ||
			Instruct == ERO64_C_0 ||
			Instruct == ERO64_4_0 ||
			Instruct == EVERS_C_0 ||
			Instruct == SEERC_C_0 ||
			Instruct == RDAY4_C_0 ||
			Instruct == RDAY4_4_0 ||
			Instruct == PRPG2_C_1 ||
			Instruct == PRPG2_4_1 ||
			Instruct == PRPG3_C_1 ||
			Instruct == PRPG3_4_1
		)
		begin
			bus_cycle_state = ADDRESS_BYTES;
		end
	end
	endtask

	task ns_from_crc_opcode;
	begin
		#1;

		if (
			Instruct == EN4BA_0_0 ||
			Instruct == EX4BA_0_0 ||
			Instruct == WRENB_0_0 ||
			Instruct == WRDIS_0_0 ||
			Instruct == WRENV_0_0 ||
			Instruct == CLPEF_0_0 ||
			Instruct == CLECC_0_0 ||
			Instruct == ENDPD_0_0 ||
			Instruct == ERCHP_0_0_60 ||
			Instruct == ERPPB_0_0 ||	
			Instruct == WRPLB_0_0 ||			
			Instruct == ERCHP_0_0_C7
		   )
		begin
			bus_cycle_state = DATA_OUT_BYTES;
		end
		else if (
				 Instruct == WRARG_C_1 ||
				 Instruct == RDARG_C_0
				)
		begin
			bus_cycle_state = ADDRESS_BYTES;
		end
		else if (
				 Instruct == RDIDN_0_0 ||
				 Instruct == RDQID_0_0 ||
				 Instruct == RDUID_0_0 ||
				 Instruct == RDSR1_0_0 ||
				 Instruct == RDPLB_0_0 ||
				 Instruct == RDSR2_0_0
				)
		begin
			bus_cycle_state = DUMMY_BYTES;
		end
		else if (
				 Instruct == WRREG_0_1 ||
				 Instruct == PGPWD_0_1 ||
				 Instruct == PRASP_0_1 ||
				 Instruct == PWDUL_0_1 ||
				 Instruct == DICHK_C_1
				)
		begin
			bus_cycle_state = DATA_IN_BYTES;
		end
	end
	endtask

	task ns_from_address;
	begin
		#1;

		if (
			Instruct == WRARG_C_1 ||
			Instruct == WRDYB_C_1 ||			
			Instruct == WRDYB_4_1 ||
			Instruct == PRPPB_C_0 ||			
			Instruct == PRPPB_4_0 ||
			Instruct == PRSSR_C_1 ||
			Instruct == PRPGE_C_1 ||
			Instruct == PRPGE_4_1 ||
			Instruct == ERO04_C_0 ||
			Instruct == ERO04_4_0 ||
			Instruct == ERO32_C_0 ||
			Instruct == ERO32_4_0 ||
			Instruct == ERO64_C_0 ||
			Instruct == ERO64_4_0 ||
			Instruct == EVERS_C_0 ||
			Instruct == SEERC_C_0 ||
			Instruct == PRPG2_C_1 ||
			Instruct == PRPG2_4_1 ||
			Instruct == PRPG3_C_1 ||
			Instruct == PRPG3_4_1
		)
		begin
			if (ITCRCE)	bus_cycle_state = CRC_ADDRESS_BYTES;
			else		bus_cycle_state = DATA_IN_BYTES;
		end
		else if (
			Instruct == RSFDP_C_0 ||
			Instruct == RDARG_C_0 ||
			Instruct == RDDYB_C_0 ||
			Instruct == RDDYB_4_0 ||
			Instruct == RDPPB_C_0 ||
			Instruct == RDPPB_4_0 ||
			Instruct == RDSSR_C_0 ||
			Instruct == RDECC_C_0 ||
			Instruct == RDECC_4_0 ||
			Instruct == RDAY7_C_0 ||
			Instruct == RDAY7_4_0 ||
			Instruct == RDAY5_C_0 ||
			Instruct == RDAY5_4_0 ||
			Instruct == RDAY2_C_0 ||
			Instruct == RDAY2_4_0 ||
			Instruct == RDAY4_C_0 ||
			Instruct == RDAY4_4_0
		)
		begin
			if (ITCRCE) bus_cycle_state = CRC_ADDRESS_BYTES;
			else		bus_cycle_state = DUMMY_BYTES;
		end
		else if (
			Instruct == RDAY1_C_0 ||
			Instruct == RDAY1_4_0
		)
		begin
			if (ITCRCE) bus_cycle_state = CRC_ADDRESS_BYTES;
			else		bus_cycle_state = DATA_OUT_BYTES;
		end
		begin
		end
	end
	endtask

	task ns_from_crc_address;
	begin
		#1;

		if (
			Instruct == WRARG_C_1 ||
			Instruct == WRDYB_C_1 ||
			Instruct == WRDYB_4_1 ||
			Instruct == PRPPB_C_0 ||
			Instruct == PRPPB_4_0 ||
			Instruct == PRSSR_C_1 ||
			Instruct == PRPGE_C_1 ||
			Instruct == PRPGE_4_1 ||
			Instruct == ERO04_C_0 ||
			Instruct == ERO04_4_0 ||
			Instruct == ERO32_C_0 ||
			Instruct == ERO32_4_0 ||
			Instruct == ERO64_C_0 ||
			Instruct == ERO64_4_0 ||
			Instruct == EVERS_C_0 ||
			Instruct == SEERC_C_0 ||
			Instruct == PRPG2_C_1 ||
			Instruct == PRPG2_4_1 ||
			Instruct == PRPG3_C_1 ||
			Instruct == PRPG3_4_1
		)
		begin
			bus_cycle_state = DATA_IN_BYTES;
		end
		else if (
			Instruct == RDARG_C_0 ||
			Instruct == RDDYB_C_0 ||
			Instruct == RDDYB_4_0 ||
			Instruct == RDPPB_C_0 ||
			Instruct == RDPPB_4_0 ||			
			Instruct == RSFDP_C_0 ||
			Instruct == RDSSR_C_0 ||
			Instruct == RDECC_C_0 ||
			Instruct == RDECC_4_0 ||
			Instruct == RDAY7_C_0 ||
			Instruct == RDAY7_4_0 ||
			Instruct == RDAY5_C_0 ||
			Instruct == RDAY5_4_0 ||
			Instruct == RDAY2_C_0 ||
			Instruct == RDAY2_4_0 ||
			Instruct == RDAY4_C_0 ||
			Instruct == RDAY4_4_0
		)
		begin
			bus_cycle_state = DUMMY_BYTES;
		end
		else if (
			Instruct == RDAY1_C_0 ||
			Instruct == RDAY1_4_0
		)
		begin
			bus_cycle_state = DATA_OUT_BYTES;
		end
	end
	endtask
	
   always @(rising_edge_CSNeg_ipd or falling_edge_CSNeg_ipd or
            rising_edge_SCK_ipd or falling_edge_SCK_ipd)
   begin: Buscycle
        integer i;
        integer j;
        integer k;
        time CLK_PER;
        time LAST_CLK;

        if (falling_edge_CSNeg_ipd)
        begin
            if (bus_cycle_state==STAND_BY)
            begin
                Instruct = NONE;
                write = 1'b1;
                cfg_write  = 0;
                opcode_cnt = 0;
                addr_cnt   = 0;
                mode_cnt   = 0;
                dummy_cnt  = 0;
                data_cnt   = 0;
				bit_cnt    = 0;
				crc_cnt    = 0; 
				crc_pass_cmd   = ~ITCRCE;
				crc_pass_pgm  = 1;
				crc_sgm_cnt = 0;
				crc_reg16_data = 16'hFFFF;
				crc_reg8_data = 8'hFF; 
				crc_reg16_pgm_data = 16'hFFFF;
				crc_reg8_pgm_data = 8'hFF;
				crc8_result = 8'hFF;
				crc_drp_cnt = 0;
				first_rd_byte   = 1;
				even        = 0;

                Data_in = {4096{1'b1}};

                CLK_PER    = 1'b0;
                LAST_CLK   = 1'b0;

                ZERO_DETECTED = 1'b0;
                DOUBLE = 1'b0;
                bus_cycle_state = OPCODE_BYTE;

				DataDriveOut_DS = 1'b0;
            end
        end

        if (rising_edge_SCK_ipd) // Instructions, addresses or data present at
        begin                    // input are latched on the rising edge of SCK

            CLK_PER = $time - LAST_CLK;
            LAST_CLK = $time;

            if (CHECK_FREQ)
            begin
                if (((Instruct == RDSSR_C_0) || ((Instruct == RDARG_C_0)  && 
                     (Address < 32'h00800000)) || (Instruct == RDPPB_4_0 || Instruct == RDPPB_C_0) ||
                   (Instruct == RDECC_4_0) || (Instruct == RDAY2_C_0)) && ~QPI_IT)
                begin
                    if ((CLK_PER <  20000 && Latency_code == 0) || // <=50MHz
                        (CLK_PER <  14705 && Latency_code == 1) || // <=68MHz
                        (CLK_PER <  12345 && Latency_code == 2) || // <=81MHz
                        (CLK_PER <  10752 && Latency_code == 3) || // <=93MHz
                        (CLK_PER <  9433  && Latency_code == 4) || // <=106MHz
                        (CLK_PER <  8475  && Latency_code == 5) || // <=118MHz
                        (CLK_PER <  7633  && Latency_code == 6) || // <=131MHz
                        (CLK_PER <  6993  && Latency_code == 7) || // <=143MHz
                        //(CLK_PER <  6410  && Latency_code == 8) || // <=156MHz
						(CLK_PER < 6000 && Latency_code == 8) ||
                        (CLK_PER <  6020  && Latency_code >= 9))   // <=166MHz
                    begin
                        $display ("More wait states are required for");
                        $display ("this clock frequency value");
                    end

                    CHECK_FREQ = 0;
                end

                if (((Instruct == RDSSR_C_0) || ((Instruct == RDARG_C_0)  && 
                     (Address < 32'h00800000)) || (Instruct == RDPPB_4_0 || Instruct == RDPPB_C_0) ||
                   (Instruct == RDECC_4_0) || (Instruct == RDAY1_4_0)) && QPI_IT && ~SDRDDR)
                begin
                    if ((CLK_PER <  20000 && Latency_code == 0) || // <=50MHz
                        (CLK_PER <  15625 && Latency_code == 1) || // <=64MHz
                        (CLK_PER <  11111 && Latency_code == 2) || // <=92MHz
                        (CLK_PER <  8264  && Latency_code == 3) || // <=121MHz
                        (CLK_PER <  6666  && Latency_code == 4) || // <=150MHz
                        (CLK_PER <  5618  && Latency_code == 5) || // <=178MHz
                        (CLK_PER <  5000  && Latency_code >= 6))   // <=200MHz
                    begin
                        $display ("More wait states are required for");
                        $display ("this clock frequency value");
                    end

                    CHECK_FREQ = 0;
                end

                if (((Instruct == RDSSR_C_0) || ((Instruct == RDARG_C_0)  && 
                     (Address < 32'h00800000)) || (Instruct == RDPPB_4_0 || Instruct == RDPPB_C_0) ||
                   (Instruct == RDECC_4_0) || (Instruct == RDAY2_4_0)) && QPI_IT && SDRDDR)
                begin
                    if ((CLK_PER <  23800 && Latency_code == 0) || // <=42MHz
                        (CLK_PER <  17544 && Latency_code == 1) || // <=57MHz
                        (CLK_PER <  11748 && Latency_code == 2) || // <=85MHz
                        (CLK_PER <  9345  && Latency_code == 3) || // <=107MHz
                        (CLK_PER <  8264  && Latency_code == 4) || // <=121MHz
                        (CLK_PER <  7407  && Latency_code == 5) || // <=135MHz
                        (CLK_PER <  6666  && Latency_code == 6) || // <=150MHz
                        (CLK_PER <  6097  && Latency_code == 7) || // <=164MHz
                        (CLK_PER <  5618  && Latency_code == 8) || // <=178MHz
                        (CLK_PER <  5208  && Latency_code == 9) || // <=192MHz
                        (CLK_PER <  5000  && Latency_code >= 10))  // <=200MHz
                    begin
                        $display ("More wait states are required for");
                        $display ("this clock frequency value");
                    end

                    CHECK_FREQ = 0;
                end

                if (((Instruct == RDARG_C_0 && (Address >= 32'h00800000)) || 
                      Instruct == RDDYB_4_0 || Instruct == RDDYB_C_0) && ~QPI_IT)
                    begin
                    if ((CLK_PER < 20000 && Register_Latency == 0) || // <=50MHz
                       (CLK_PER <  7510 && Register_Latency == 1)  || // <=133MHz
                       (CLK_PER <  6020 && Register_Latency == 2)) // <=166MHz
                    begin
                        $display ("More wait states are required for");
                        $display ("this clock frequency value");
                    end

                    CHECK_FREQ = 0;
                end

                if   ((Instruct == RDSR1_0_0  ||
                     Instruct == RDSR2_0_0 || Instruct == RDPLB_0_0) && ~QPI_IT)
                    begin
                    if ((CLK_PER < 20000 && Register_Latency == 0) || // <=50MHz
                       (CLK_PER <  7510 && Register_Latency == 0) || // <=133MHz
                       (CLK_PER <  7510 && Register_Latency == 1) || // <=133MHz
                       (CLK_PER <  6020 && Register_Latency == 2)) // <=166MHz
                    begin
                        $display ("More wait states are required for");
                        $display ("this clock frequency value");
                    end

                    CHECK_FREQ = 0;
                end

                if   ((Instruct == RDSR1_0_0  || Instruct == RDDYB_4_0 || Instruct == RDDYB_C_0 ||
                      (Instruct == RDARG_C_0 && (Address >= 32'h00800000)) ||
                     Instruct == RDSR2_0_0 || Instruct == RDPLB_0_0) && QPI_IT && ~SDRDDR)
                    begin
                    if ((CLK_PER < 20000 && Register_Latency == 3) || // <=50MHz
                       (CLK_PER <  7510 && Register_Latency == 4) || // <=133MHz
                       (CLK_PER <  6020 && Register_Latency == 5) || // <=133MHz
                       (CLK_PER <  5000 && Register_Latency == 6)) // <=166MHz
                    begin
                        $display ("More wait states are required for");
                        $display ("this clock frequency value");
                    end

                    CHECK_FREQ = 0;
                end

                if   ((Instruct == RDSR1_0_0  || Instruct == RDDYB_4_0 || Instruct == RDDYB_C_0 ||
                      (Instruct == RDARG_C_0 && (Address >= 32'h00800000)) ||
                     Instruct == RDSR2_0_0 || Instruct == RDPLB_0_0) && QPI_IT && SDRDDR)
                    begin
                    if ((CLK_PER < 40000 && Register_Latency == 3) || // <=25MHz
                       (CLK_PER <  15151 && Register_Latency == 4) || // <=66MHz
                       (CLK_PER <  5000 && Register_Latency == 5) || // <=200MHz
                       (CLK_PER <  5000 && Register_Latency == 6)) // <=200MHz
                    begin
                        $display ("More wait states are required for");
                        $display ("this clock frequency value");
                    end

                    CHECK_FREQ = 0;
                end
            end
        end

        if (rising_edge_CSNeg_ipd)
        begin
			//Expecting last state for bus_cycle_state is always DATA_BYTES
			//regardless of the command
            if (
				bus_cycle_state != DATA_IN_BYTES &&
				bus_cycle_state != DATA_OUT_BYTES &&
				bus_cycle_state != CRC_DATA_IN_BYTES &&
				bus_cycle_state != CRC_DATA_OUT_BYTES
			)
            begin
                bus_cycle_state = STAND_BY;
            end
            else
            begin
                bus_cycle_state = STAND_BY;

                if (rd_crc != 0)
                begin
                     rd_crc = 0;
                     ICRV = 32'hFFFFFFFF;
                     icrc_out = 32'hFFFFFFFF;
                     icrc_cnt = 0;  
                end
                
                case (Instruct)
                    WRENB_0_0,
					WRENV_0_0,
                    WRDIS_0_0,
                    ERCHP_0_0_60,
					ERCHP_0_0_C7,
                    ER256_4_0,
					ERO04_C_0,
                    ERO04_4_0,
					ERO32_C_0,
					ERO32_4_0,
					ERO64_C_0,
					ERO64_4_0,
                    ENDPD_0_0,
                    CLPEF_0_0,
                    SRSTE_0_0,
                    SFRST_0_0,
                    EN4BA_0_0,
                    EX4BA_0_0,
                    ERPPB_0_0,
                    PRPPB_4_0,
                    WRPLB_0_0,
                    EVERS_C_0,
                    SPEPD_0_0,
                    RSEPD_0_0,
                    SEERC_C_0,
                    DICHK_C_1:
                    begin
                        if (Instruct == ERCHP_0_0_60 || Instruct == ERCHP_0_0_C7 || Instruct == ER256_4_0 ||
							Instruct == ERO04_C_0 || Instruct == ERO04_4_0 || Instruct == ERO32_C_0 ||
							Instruct == ERO32_4_0 || Instruct == ERO64_C_0 || Instruct == ERO64_4_0 ||
							Instruct == ERPPB_0_0 || Instruct == PRPPB_4_0)
                            prog_erase = 1'b1;

                        if (data_cnt == 0)
                            write = 1'b0;
                    end

					WRREG_0_1:
					begin
						write = 1'b0;
					end

                    WRARG_C_1: //Avi
                    begin
                        if (QPI_IT)
                        begin
						    if(ITCRCE) 
							begin
								if (data_cnt == 4)  
								begin
									write = 1'b0;

									WRAR_reg_in = {quad_data_in[0],quad_data_in[1]};
									WRAR_reg_inbar = {quad_data_in[2],quad_data_in[3]};  

									if(WRAR_reg_in == ~WRAR_reg_inbar)
									begin
									   WRAR_reg_in_correct = 1'b1;
									end
									else 
									begin
									   WRAR_reg_in_correct = 1'b0;
									   INS1V[0] = 0;
									end
								end
							end
							else
							begin
								if (data_cnt == 2)  
								begin
									write = 1'b0;
									WRAR_reg_in = {quad_data_in[0],quad_data_in[1]};
								end
							end
                        end
                        else
                        begin
						    if(ITCRCE) 
							begin
								if (data_cnt == 16)  
								begin
									write = 1'b0;

									WRAR_reg_in[7:0]    = Data_in[7:0];
									WRAR_reg_inbar[7:0] = Data_in[15:8]; 

									//display("Data_inB0: 0x%h, ~Data_inB1: 0x%h", Data_in[7:0], ~Data_in[15:8]);

									if(WRAR_reg_in == ~WRAR_reg_inbar) // To avoid race condition
									begin  
									   WRAR_reg_in_correct = 1'b1;
									   //$display("if WRAR_reg_in_correct: 0x%h", WRAR_reg_in_correct);
									end
									else
									begin
									   //$display("else WRAR_reg_in_correct: 0x%h", WRAR_reg_in_correct);
									   WRAR_reg_in_correct = 1'b0;
									   INS1V[0] = 0; 
									end
								end
							end
							else
							begin
								if (data_cnt == 8)  
								begin
									write = 1'b0;

									WRAR_reg_in[7:0] = Data_in[7:0];
								end
							end
					    end
                    end
			
                    PRPGE_4_1, PRPGE_C_1, PRPG2_C_1, PRPG2_4_1, PRPG3_C_1, PRPG3_4_1:
                    begin
                        prog_erase = 1'b1;
                        ECC_data = Address - (Address % 16);

                        if (~QPI_IT && Instruct != PRPG2_C_1 && Instruct != PRPG2_4_1 && Instruct != PRPG3_C_1 && Instruct != PRPG3_4_1)
                        begin
                            if (data_cnt > 0)
                            begin
							    //data_cnt = data_cnt - crc_drp_cnt;  // Remove CRC bytes, crc_drp_cnt =0 when ITCRCE=0

                                if ((data_cnt % 8) == 0)
                                begin
                                    write = 1'b0;

                                    for(i=0;i<=PageSize;i=i+1)
                                    begin
                                        for(j=7;j>=0;j=j-1)
                                        begin
                                            /*if ((Data_in[(i*8)+(7-j)]) !== 1'bX)
                                            begin
                                                Byte_slv[j] = Data_in[(i*8)+(7-j)];

                                                if (Data_in[(i*8)+(7-j)]==1'b0)
                                                begin
                                                    ZERO_DETECTED = 1'b1;
                                                end
                                            end*/

											if (Data_in[(i*8)+j] !== 1'bX)
											begin
												Byte_slv[j] = Data_in[(i*8)+j];

												if (Data_in[(i*8)+j]==1'b0)
												begin
													ZERO_DETECTED = 1'b1;
												end
											end
                                        end
                                        WByte[i] = Byte_slv;
                                    end

                                    if (data_cnt/8 > (PageSize+1)*BYTE)
                                        Byte_number = PageSize;
                                    else
										Byte_number = data_cnt/8;

                                    if (((Address % 16) + Byte_number+1) % 16 == 0)
                                        ECC_check = ((Address % 16) + Byte_number+1) / 16;
                                    else
                                        ECC_check = ((Address % 16) + Byte_number+1) / 16 + 1;
                                end
                            end
                        end
                        else
                        begin
                            if ((data_cnt > 0) && ((data_cnt % 2) == 0))
                            begin 
							    data_cnt = data_cnt - crc_drp_cnt;  // Remove CRC bytes, crc_drp_cnt =0 when ITCRCE=0
                                write = 1'b0;

                                for(i=0;i<=PageSize;i=i+1)
								begin
									for(j=1;j>=0;j=j-1)
									begin
										Quad_slv =
										quad_data_in[(i*2)+(1-j)];
										if (j==1)
											Byte_slv[7:4] = Quad_slv;
										else if (j==0)
											Byte_slv[3:0] = Quad_slv;
									end
									WByte[i] = Byte_slv;
								end
                                if (data_cnt > (PageSize+1)*2)
                                    Byte_number = PageSize;
                                else
                                    Byte_number = data_cnt/2-1;
                                if (((Address % 16) + Byte_number+1) % 16 == 0)
                                    ECC_check = ((Address % 16) + Byte_number+1) / 16;
                                else
                                    ECC_check = ((Address % 16) + Byte_number+1) / 16 + 1;
                            end
                        end
                        ADDRHILO_PG(AddrLo, AddrHi, ECC_data);
                        cnt = 0;
                    end
                   
                    PRSSR_C_1:
                    begin
                        prog_erase = 1'b1;
                        ECC_data = Address - (Address % 16);

                        if (~QPI_IT)
                        begin
                            if (data_cnt > 0 && data_cnt % 8 == 0)
                            begin
                                //if ((data_cnt % 8) == 0)
                                //begin
                                    write = 1'b0;

                                    for(i=0;i<=PageSize;i=i+1)
                                    begin
                                        for(j=7;j>=0;j=j-1)
                                        begin
                                            /*if ((Data_in[(i*8)+(7-j)]) !== 1'bX)
                                            begin
                                                Byte_slv[j] = Data_in[(i*8)+(7-j)];

                                                if (Data_in[(i*8)+(7-j)]==1'b0)
                                                begin
                                                    ZERO_DETECTED = 1'b1;
                                                end
                                            end*/

											if (Data_in[(i*8)+j] !== 1'bX)
											begin
												Byte_slv[j] = Data_in[(i*8)+j];

												if (Data_in[(i*8)+j]==1'b0)
												begin
													ZERO_DETECTED = 1'b1;
												end
											end
                                        end

                                        WByte[i] = Byte_slv;
                                    end

                                    if (data_cnt/8 > (PageSize+1)*BYTE)
									begin
                                        Byte_number = PageSize;
									end
                                    else
									begin
										Byte_number = data_cnt/8 - ITCRCE;
									end

                                    if (((Address % 16) + Byte_number+1) % 16 == 0)
                                        ECC_check = ((Address % 16) + Byte_number+1) / 16;
                                    else
                                        ECC_check = ((Address % 16) + Byte_number+1) / 16 + 1;
                                //end
                            end
                        end
                        else
                        begin
                            if ((data_cnt > 0) && ((data_cnt % 2) == 0))
                            begin
                                write = 1'b0;

                                for(i=0;i<=PageSize;i=i+1)
								begin
									for(j=1;j>=0;j=j-1)
									begin
										Quad_slv =
										quad_data_in[(i*2)+(1-j)];

										if (j==1)
											Byte_slv[7:4] = Quad_slv;
										else if (j==0)
											Byte_slv[3:0] = Quad_slv;
									end
									
									WByte[i] = Byte_slv;
								end
							
                                if (data_cnt > (PageSize+1)*2)
                                    Byte_number = PageSize;
                                else
								begin
									Byte_number = data_cnt/2;
								end

								if (SDRDDR && ITCRCE)
								begin
									Byte_number = Byte_number - 1;
								end

                                if (((Address % 16) + Byte_number+1) % 16 == 0)
                                    ECC_check = ((Address % 16) + Byte_number+1) / 16;
                                else
                                    ECC_check = ((Address % 16) + Byte_number+1) / 16 + 1;
                            end
                        end

                        for (i=0;i<=(ECC_check*16-1);i=i+1)
                        begin
//                             ReturnSectorID(sect,ECC_data);
                            memory_features_i0.read_mem_w(
                                mem_data,
                                ECC_data + i - cnt
                                );

                            if (mem_data !== MaxData)
                            begin
                                ECC_ERR = ECC_ERR + 1;

                            end
                        end
                    end

                    WRDYB_4_1,WRDYB_C_1:
                    begin
                        if (QPI_IT)
                        begin
						    if(ITCRCE) 
							begin
								if (data_cnt == 4)  
								begin
									write = 1'b0;

									DYAV_in = {quad_data_in[0],quad_data_in[1]};
									DYAV_inbar = {quad_data_in[2],quad_data_in[3]};  

									if(DYAV_in == ~DYAV_inbar)
									begin
									   DYAV_in_correct = 1'b1;
									end
									else 
									begin
									   DYAV_in_correct = 1'b0;
									   INS1V[0] = 0;
									end
								end
							end
							else
							begin
								if (data_cnt == 2)  
								begin
									write = 1'b0;
									DYAV_in = {quad_data_in[0],quad_data_in[1]};
								end
							end
                        end
                        else
                        begin
						    if(ITCRCE) 
							begin
								if (data_cnt == 16)  
								begin
									write = 1'b0;

									DYAV_in[7:0]    = Data_in[7:0];
									DYAV_inbar[7:0] = Data_in[15:8]; 

									//display("Data_inB0: 0x%h, ~Data_inB1: 0x%h", Data_in[7:0], ~Data_in[15:8]);

									if(DYAV_in == ~DYAV_inbar) // To avoid race condition
									begin  
									   DYAV_in_correct = 1'b1;
									   //$display("if WRAR_reg_in_correct: 0x%h", WRAR_reg_in_correct);
									end
									else
									begin
									   //$display("else WRAR_reg_in_correct: 0x%h", WRAR_reg_in_correct);
									   DYAV_in_correct = 1'b0;
									   INS1V[0] = 0; 
									end
								end
							end
							else
							begin
								if (data_cnt == 8)  
								begin
									write = 1'b0;

									DYAV_in[7:0] = Data_in[7:0];
								end
							end
					    end
                    end
						
				    PGPWD_0_1:  
                    begin
						if (QPI_IT)
						begin
							if (ITCRCE)
							begin
								if (data_cnt == 32)
								begin
									write = 1'b0;
									PWDO_in[7:0]      = {quad_data_in[0], quad_data_in[1]};
									PWDO_in[15:8]     = {quad_data_in[2], quad_data_in[3]};
									PWDO_in[23:16]    = {quad_data_in[4], quad_data_in[5]};
									PWDO_in[31:24]    = {quad_data_in[6], quad_data_in[7]};
									PWDO_in[39:32]    = {quad_data_in[8], quad_data_in[9]};
									PWDO_in[47:40]    = {quad_data_in[10], quad_data_in[11]};
									PWDO_in[55:48]    = {quad_data_in[12], quad_data_in[13]};
									PWDO_in[63:56]    = {quad_data_in[14], quad_data_in[15]};
								end
							end
							else
							begin
								if (data_cnt == 16)
								begin
									write = 1'b0;
									PWDO_in[7:0]      = {quad_data_in[0], quad_data_in[1]};
									PWDO_in[15:8]     = {quad_data_in[2], quad_data_in[3]};
									PWDO_in[23:16]    = {quad_data_in[4], quad_data_in[5]};
									PWDO_in[31:24]    = {quad_data_in[6], quad_data_in[7]};
									PWDO_in[39:32]    = {quad_data_in[8], quad_data_in[9]};
									PWDO_in[47:40]    = {quad_data_in[10], quad_data_in[11]};
									PWDO_in[55:48]    = {quad_data_in[12], quad_data_in[13]};
									PWDO_in[63:56]    = {quad_data_in[14], quad_data_in[15]};
								end
							end
						end
						else
						begin
							if (ITCRCE)
							begin
								if (data_cnt == 128)
								begin
									write = 1'b0;
									PWDO_in = Data_in[63:0];
								end
							end
							else
							begin
								if (data_cnt == 64)
								begin
									write = 1'b0;
									PWDO_in = Data_in[63:0];
								end
							end
						end
					end
				
					PRASP_0_1:  
                    begin
						if (QPI_IT)
						begin
							if (ITCRCE)
							begin
								if (data_cnt == 32)
								begin
									write = 1'b0;									
									ASPO_in[7:0]      = {quad_data_in[0], quad_data_in[1]};
									ASPO_in[15:8]     = {quad_data_in[2], quad_data_in[3]};

								end
							end
							else
							begin
								if (data_cnt == 4)
								begin
									write = 1'b0;
									ASPO_in[7:0]      = {quad_data_in[0], quad_data_in[1]};
									ASPO_in[15:8]     = {quad_data_in[2], quad_data_in[3]};
								end
							end
						end
						else
						begin
							if (ITCRCE)
							begin
								if (data_cnt == 128)
								begin
									write = 1'b0;
								    ASPO_in = Data_in[15:0];
								end
							end
							else
							begin
								if (data_cnt == 16)
								begin
									write = 1'b0;
									ASPO_in = Data_in[15:0];
								end
							end
						end
                    end						
				
					PWDUL_0_1:  
                    begin
						if (QPI_IT)
						begin
							if (ITCRCE)
							begin
								if (data_cnt == 32)
								begin
									write = 1'b0;
									PASS_TEMP[7:0]      = {quad_data_in[0], quad_data_in[1]};
									PASS_TEMP[15:8]     = {quad_data_in[2], quad_data_in[3]};
									PASS_TEMP[23:16]    = {quad_data_in[4], quad_data_in[5]};
									PASS_TEMP[31:24]    = {quad_data_in[6], quad_data_in[7]};
									PASS_TEMP[39:32]    = {quad_data_in[8], quad_data_in[9]};
									PASS_TEMP[47:40]    = {quad_data_in[10], quad_data_in[11]};
									PASS_TEMP[55:48]    = {quad_data_in[12], quad_data_in[13]};
									PASS_TEMP[63:56]    = {quad_data_in[14], quad_data_in[15]};
								end
							end
							else
							begin
								if (data_cnt == 16)
								begin
									write = 1'b0;
									PASS_TEMP[7:0]      = {quad_data_in[0], quad_data_in[1]};
									PASS_TEMP[15:8]     = {quad_data_in[2], quad_data_in[3]};
									PASS_TEMP[23:16]    = {quad_data_in[4], quad_data_in[5]};
									PASS_TEMP[31:24]    = {quad_data_in[6], quad_data_in[7]};
									PASS_TEMP[39:32]    = {quad_data_in[8], quad_data_in[9]};
									PASS_TEMP[47:40]    = {quad_data_in[10], quad_data_in[11]};
									PASS_TEMP[55:48]    = {quad_data_in[12], quad_data_in[13]};
									PASS_TEMP[63:56]    = {quad_data_in[14], quad_data_in[15]};
								end
							end
						end
						else
						begin
							if (ITCRCE)
							begin
								if (data_cnt == 128)
								begin
									write = 1'b0;
									PASS_TEMP = Data_in[63:0];
								end
							end
							else
							begin
								if (data_cnt == 64)
								begin
									write = 1'b0;
									PASS_TEMP = Data_in[63:0];
								end
							end
						end
                    end												
												
                endcase
            end
        end
    end

///////////////////////////////////////////////////////////////////////////////
// Timing control for the Page Program
///////////////////////////////////////////////////////////////////////////////
    time  pob;
    time  elapsed_pgm;
    time  start_pgm;
    time  duration_pgm;
    event pdone_event;

    always @(rising_edge_PSTART or rising_edge_reseted)
    begin : ProgTime

        if (CFR3V[4] == 1'b0)  //Program uffer size selection - 0 -256, 1 -512
        begin
            if (param_sec_write_time==1'b1)
            begin
                pob = tdevice_PP_256;
            end
            else 
            begin
                pob = tdevice_PP_256;
            end
        end
        else
        begin
            if (param_sec_write_time==1'b1)
            begin
                pob = tdevice_PP_256;
            end
            else 
            begin
                pob = tdevice_PP_256;
            end
        end

        if (rising_edge_reseted)
        begin
            PDONE = 1; // reset done, programing terminated
            disable pdone_process;
        end
        else if (reseted)
        begin
            if (rising_edge_PSTART && PDONE)
            begin
                elapsed_pgm = 0;
                duration_pgm = pob;
                PDONE = 1'b0;
                start_pgm = $time;
                ->pdone_event;
            end
        end
    end

    always @(posedge PGSUSP)
    begin
        if (PGSUSP && (~PDONE))
        begin
            disable pdone_process;
            elapsed_pgm = $time - start_pgm;
            duration_pgm = pob - elapsed_pgm;
            PDONE = 1'b0;
        end
    end

    always @(posedge PGRES)
    begin
        start_pgm = $time;
        ->pdone_event;
    end

    always @(pdone_event)
    begin : pdone_process
        #(duration_pgm) PDONE = 1;
    end

///////////////////////////////////////////////////////////////////////////////
// Timing control for the Write Status Register
///////////////////////////////////////////////////////////////////////////////
    time  wob;
    event wdone_event;
    event csdone_event;

    always @(rising_edge_WSTART or rising_edge_reseted)
    begin:WriteTime

        wob = tdevice_WRR;

        if (rising_edge_reseted)
        begin
            WDONE = 1; // reset done, Write terminated
            disable wdone_process;
        end
        else if (reseted)
        begin
            if (rising_edge_WSTART && WDONE)
            begin
                WDONE = 1'b0;
                -> wdone_event;
            end
        end
    end

    always @(wdone_event)
    begin : wdone_process
        #wob WDONE = 1;
    end

   always @(posedge CSSTART or rising_edge_reseted)
   begin:WriteVolatileBitsTime

        if (rising_edge_reseted)
        begin
            CSDONE = 1; // reset done, Write terminated
            disable csdone_process;
        end
        else if (reseted)
        begin
            if (CSSTART && CSDONE)
            begin
                CSDONE = 1'b0;
                -> csdone_event;
            end
        end
    end

    always @(csdone_event)
    begin : csdone_process
        if (read_transaction)
            #tdevice_CSR CSDONE = 1;
        else
            #tdevice_CS CSDONE = 1;
    end

///////////////////////////////////////////////////////////////////////////////
// Timing control for Evaluate Erase Status
///////////////////////////////////////////////////////////////////////////////
    event eesdone_event;

    always @(rising_edge_EESSTART or rising_edge_reseted)
    begin:EESTime

        if (rising_edge_reseted)
        begin
            EESDONE = 1; // reset done, Write terminated
            disable eesdone_process;
        end
        else if (reseted)
        begin
            if (rising_edge_EESSTART && EESDONE)
            begin
                EESDONE = 1'b0;
                -> eesdone_event;
            end
        end
    end

    always @(eesdone_event)
    begin : eesdone_process
        #tdevice_EES EESDONE = 1;
    end

///////////////////////////////////////////////////////////////////////////////
// Timing control for Erase
///////////////////////////////////////////////////////////////////////////////
    event edone_event;
    time elapsed_ers;
    time start_ers;
    time duration_ers;

    always @(rising_edge_ESTART or rising_edge_reseted)
    begin : ErsTime

        if (Instruct == ERCHP_0_0_60 || Instruct == ERCHP_0_0_C7)
        begin
            duration_ers = tdevice_CE;
        end
		else if (Instruct == ERO32_C_0 || Instruct == ERO32_4_0)
		begin
			duration_ers = tdevice_HBE;
		end
		else if (Instruct == ERO64_C_0 || Instruct == ERO64_4_0)
		begin
			duration_ers = tdevice_BE;
		end
        else if (Instruct == ERO04_4_0)
        begin
            duration_ers = tdevice_SE4;
        end
        else
        begin
            duration_ers = tdevice_SE4;
        end

        if (rising_edge_reseted)
        begin
            EDONE = 1; // reset done, ERASE terminated
            disable edone_process;
        end
        else if ((reseted) && (rising_edge_ESTART))
        begin
            elapsed_ers = 0;
            EDONE = 1'b0;
            start_ers = $time;
            ->edone_event;
        end
    end

    always @(posedge ESUSP)
    begin
        if (ESUSP && (~EDONE))
        begin
            disable edone_process;
            elapsed_ers = $time - start_ers;
            duration_ers = tdevice_SE4 - elapsed_ers;
            EDONE = 1'b0;
        end
    end

    always @(posedge ERES)
    begin
        if  (ERES && (~EDONE))
        begin
            start_ers = $time;
            ->edone_event;
        end
    end

    always @(edone_event)
    begin : edone_process
        EDONE = 1'b0;
        #duration_ers EDONE = 1'b1;
    end

    // SEERC_DONE timing process
    always @(rising_edge_SEERC_START)
    begin : seerc_done_process
        SEERC_DONE          = 1'b0;
        #tdevice_SEERC SEERC_DONE = 1'b1;
    end

    ///////////////////////////////////////////////////////////////////
    // Timing control for the suspend process
    ///////////////////////////////////////////////////////////////////
    always @(rising_edge_START_T1_in)
    begin : Start_T1_time
        if (rising_edge_START_T1_in)
        begin
            if (CRC_ACT == 1'b1)
            begin
                sSTART_T1 = 1'b0;
                sSTART_T1 <= #tdevice_CRCSL 1'b1;
            end
            else
            begin
                sSTART_T1 = 1'b0;
                sSTART_T1 <= #tdevice_SUSP 1'b1;
            end
        end
        else
        begin
            sSTART_T1 = 1'b0;
        end
    end

    ///////////////////////////////////////////////////////////////////
    // Timing control for the CRC calculation
    ///////////////////////////////////////////////////////////////////
    event crcdone_event;
    time elapsed_crc;
    time start_crc;
    time crc_duration;

    always @(rising_edge_CRCSTART or rising_edge_reseted)
    begin : CRCTime

        if (rising_edge_reseted)
        begin
            CRCDONE = 1;
            disable crcdone_process;
        end
        else if (reseted)
        begin
            if ((rising_edge_CRCSTART) && CRCDONE)
            begin
                crc_duration = tdevice_CRCSETUP;
                elapsed_crc = 0;
                CRCDONE = 1'b0;
                start_crc = $time;
                -> crcdone_event;
            end
        end
    end

    always @(posedge CRCSUSP)
    begin
        if (CRCSUSP && (~CRCDONE))
        begin
            disable crcdone_process;
            elapsed_crc = $time - start_crc;
            crc_duration = crc_duration - elapsed_crc;
            CRCDONE = 1'b0;
        end
    end

    always @(posedge CRCRES)
    begin
        start_crc = $time;
        ->crcdone_event;
    end

    always @(crcdone_event)
    begin : crcdone_process
        #(crc_duration) CRCDONE = 1;
    end

    ///////////////////////////////////////////////////////////////////
    // Process for clock frequency determination
    ///////////////////////////////////////////////////////////////////
    always @(posedge SCK_ipd)
    begin : clock_period
        if (SCK_ipd)
        begin
            SCK_cycle = $time - prev_SCK;
            prev_SCK = $time;
        end
    end

//    /////////////////////////////////////////////////////////////////////////
//    // Main Behavior Process
//    // combinational process for next state generation
//    /////////////////////////////////////////////////////////////////////////

    integer i;
    integer j;

    always @(rising_edge_PoweredUp or falling_edge_write or rising_edge_WDONE or
           rising_edge_PDONE or rising_edge_EDONE or rising_edge_RST_out or falling_edge_RST or
           rising_edge_SWRST_out or rising_edge_CSDONE or rising_edge_BCDONE or
           PRGSUSP_out_event or ERSSUSP_out_event or falling_edge_PASSULCK_in or
           rising_edge_EESDONE or falling_edge_PPBERASE_in or rising_edge_CRCDONE or
           posedge DPD_entered or rising_edge_DPD_out or rising_edge_RESETNeg or
           rising_edge_SEERC_DONE or rising_edge_DPD_POR_out)
    begin: StateGen1

        integer sect;

        if (rising_edge_PoweredUp && SWRST_out && RST_out)
        begin
            if (ATBTEN == 1 && ASPRDP !== 0 )
            begin
                next_state     = AUTOBOOT;
                read_cnt       = 0;
                byte_cnt       = 1;
                read_addr      = {ATBN[31:9], 9'b0};
                start_delay    = ATBN[8:1];
                start_autoboot = 0;
                ABSD           = ATBN[8:1];
                CFR4N[4]      = 1'b0;
            end
            else if (DPDPOR == 1'b0) 
                next_state = IDLE;
            else
                next_state = DP_DOWN;
        end
        else if (PoweredUp)
        begin
            if (RST_out == 1'b0)
                next_state = current_state;
            else if (falling_edge_write && Instruct == SFRST_0_0 && RESET_EN)
            begin
                if (ATBTEN == 1 && ASPRDP !== 0)
                begin
                    read_cnt       = 0;
                    byte_cnt       = 1;
                    read_addr      = {ATBN[31:9], 9'b0};
                    start_delay    = ATBN[8:1];
                    ABSD           = ATBN[8:1];
                    start_autoboot = 0;
                    CFR4N[4]      = 1'b0;
                    next_state     = AUTOBOOT;
                end
            else if (CFR4N[2] == 1'b1 && CSNeg_ipd==1'b1 && !DPD_POR_out)
                next_state = DP_DOWN;
            else
                next_state = IDLE;
            end
            else
            begin
                case (current_state)
                    RESET_STATE :
                    begin
                        if (rising_edge_RST_out || rising_edge_SWRST_out)
                        begin
                            if (ATBTEN == 1 && ASPRDP!== 0)
                            begin
                                next_state = AUTOBOOT;
                                CFR4N[4]      = 1'b0;
                                read_cnt       = 0;
                                byte_cnt       = 1;
                                read_addr      = {ATBN[31:9],9'b0};
                                start_delay    = ATBN[8:1];
                                start_autoboot = 0;
                                ABSD           = ATBN[8:1];
                            end
                            else if (CFR4N[2] == 1'b1 && CSNeg_ipd==1'b1 && !DPD_POR_out)
                                next_state = DP_DOWN;
                            else 
                                next_state = IDLE;
                        end
                    end

                    IDLE :
                    begin
                        if (falling_edge_write)
                        begin
							if (Instruct==WRREG_0_1)
							begin
								next_state = WRITE_ALL_REG;
							end
							else if (((Instruct == WRARG_C_1 && WRPGEN == 1) && crc_pass_cmd && ITCRCE) ||
					         ((Instruct == WRARG_C_1 && WRPGEN == 1) && !ITCRCE))
                            begin
                            // can not execute if WRPGEN bit is zero or Hardware
                            // Protection Mode is entered and SR1NV,SR1V,CR1NV or
                            // CR1V is selected (no error is set)
                                if ((Address == 32'h00000001)  ||
                                   ((Address >  32'h00000006)  &&
                                    (Address <  32'h00000010)) ||
                                   ((Address >  32'h00000011)  &&
                                    (Address <  32'h00000020)) ||
                                   ((Address >  32'h00000027)  &&
                                    (Address <  32'h00000030)) ||
                                   ((Address >  32'h00000031)  &&
                                    (Address <  32'h00000042)) ||
                                   ((Address >  32'h00000045)  &&
                                    (Address <  32'h00800000)) ||
                                   ((Address >  32'h00800006)  &&
                                    (Address <  32'h00800008)) ||
                                   ((Address >  32'h00800008)  &&
                                    (Address <  32'h00800010)) ||
                                   ((Address >  32'h00800011)  &&
                                    (Address <  32'h00800040)) ||
                                   ((Address >  32'h00800045)  &&
                                    (Address < 32'h00800067))  ||
                                   ((Address >  32'h00800068)  &&
                                    (Address < 32'h00800070))  ||
                                   (Address ==  32'h00800078)  ||
                                   ((Address >  32'h00800080)  &&
                                    (Address < 32'h00800089))  ||
                                   (Address ==  32'h00800094)  ||
                                   ((Address >  32'h00800098)  &&
                                    (Address < 32'h0080009B))  ||
                                    (Address >  32'h0080009B))
                                begin
                                    $display ("WARNING: Undefined location ");
                                    $display (" selected. Command is ignored!");
                                end
                                else if ((Address > 32'h00800094) &&
                                         (Address < 32'h00800099)) // CRC
                                begin
                                    $display ("WARNING: CRC register cannot be ");
                                    $display ("written by the WRARG_C_1 command. ");
                                    $display ("Command is ignored!");
                                end
                                else if (Address == 32'h0080009B) // PPBL
                                begin
                                    $display ("WARNING: PPLV register cannot be ");
                                    $display ("written by the WRARG_C_1 command. ");
                                    $display ("Command is ignored!");
                                end
                                else if ((Address == 32'h00000002) &&
                                    ((PLPROT_O == 1 && WRAR_reg_in[4] == 1'b0) ))
                                begin
                                    $display ("WARNING: Writing of OTP bits back ");
                                    $display ("to their default state is ignored ");
                                    $display ("and no error is set!");

                                end
                                else if ((~(ASPPWD && ASPPER)) &&
                                        (Address == 32'h00000030  || // ASPO[7:0]
                                        Address == 32'h00000031))    // ASPO[15:8]
                                begin
                                // Once the protection mode is selected,the OTP
                                // bits are permanently protected from programming
                                        next_state = PGERS_ERROR;
                                end
                                else if (~(ASPPER))
                                begin
                                // Once the protection mode is selected,the OTP
                                // bits are permanently protected from programming
                                    if (
                                        Address == 32'h00000020  || // PASS[7:0]
                                        Address == 32'h00000021  || // PASS[15:8]
                                        Address == 32'h00000022  || // PASS[23:16]
                                        Address == 32'h00000023  || // PASS[31:24]
                                        Address == 32'h00000024  || // PASS[39:32]
                                        Address == 32'h00000025  || // PASS[47:40]
                                        Address == 32'h00000026  || // PASS[55:48]
                                        Address == 32'h00000027  || // PASS[63:56]
                                        Address == 32'h00000030  || // ASPR[7:0]
                                        Address == 32'h00000031 //||  // ASPR[15:8]
										//((WRAR_reg_in[5] == 1'b1 || WRAR_reg_in[4] == 1'b1 || WRAR_reg_in[2] == 1'b1) && Address == 32'h00000002) || // CR1NV
										//(WRAR_reg_in[3] == 1'b1 && Address == 32'h00000004)
										)						   
                                    begin
                                        next_state = PGERS_ERROR;
                                    end
                                    else
                                        next_state = WRITE_ANY_REG;
                                end
                                else // Protection Mode not selected
                                begin
                                    if ((Address == 32'h00000030) ||
                                        (Address == 32'h00000031))//ASPR
                                    begin
                                        if (WRAR_reg_in[2] == 1'b0 &&
                                            WRAR_reg_in[1] == 1'b0 &&
                                            Address == 32'h00000030)
                                            next_state = PGERS_ERROR;
                                        else
                                            next_state = WRITE_ANY_REG;
                                    end
                                    else
                                        next_state = WRITE_ANY_REG;
                                end
                            end
                            else if ((Instruct==PRPGE_4_1 || Instruct==PRPGE_C_1 || Instruct==PRPG2_C_1 || Instruct==PRPG2_4_1 || Instruct==PRPG3_C_1 || Instruct==PRPG3_4_1)
									 && WRPGEN == 1 && crc_pass_cmd  && crc_pass_pgm)
                            begin
                                ReturnSectorID(sect,Address);

                                if (Sec_Prot[sect]== 0 && PPB_bits[sect]== 1 &&
                                    DYB_bits[sect]== 1)
                                begin
                                    next_state = PAGE_PG;
                                end
                                else
                                    next_state = PGERS_ERROR;
                            end
                            else if (Instruct == PRSSR_C_1 && WRPGEN == 1)
                            begin
                                if (Address + Byte_number <= OTPHiAddr)
                                begin //Program within valid OTP Range
                                    if (((((Address>=16'h0010 && Address<=16'h00FF))
                                        && LOCK_BYTE1[Address/32] == 1) ||
                                        ((Address>=16'h0100 && Address<=16'h01FF)
                                        && LOCK_BYTE2[(Address-16'h0100)/32]==1) ||
                                        ((Address>=16'h0200 && Address<=16'h02FF)
                                        && LOCK_BYTE3[(Address-16'h0200)/32]==1) ||
                                        ((Address>=16'h0300 && Address<=16'h03FF)
                                        && LOCK_BYTE4[(Address-16'h0300)/32] == 1)))
                                    begin
//                                         if (TLPROT == 0)
                                            next_state = OTP_PG;
//                                         else
                                   //rev N, TLPROT no longer protects SSR region(OTP)
                                        //Attempting to program within valid OTP
                                        //range while TLPROT = 1
//                                             next_state = PGERS_ERROR;
                                    end
                                    else if (ZERO_DETECTED)
                                    begin
                                    //Attempting to program any zero in the 16
                                    //lowest bytes or attempting to program any zero
                                    //in locked region
                                        next_state = PGERS_ERROR;
                                    end
                                end
                            end
                            else if ((Instruct==ER256_4_0) && WRPGEN == 1)
                            begin
                                ReturnSectorID(sect,Address);

                                if (UniformSec || (TopBoot && !BottomBoot && (sect < 255)) ||
                                (!TopBoot && BottomBoot && sect > 32) || (TopBoot && BottomBoot
                                && (sect > 16 && sect < 271))) 
                                begin
                                    if (Sec_Prot[sect]== 0 && PPB_bits[sect]== 1
                                        && DYB_bits[sect]== 1)
                                    begin
                                        if (~CFR3V[5])
                                            next_state = SECTOR_ERS;
                                        else
                                            next_state = BLANK_CHECK;
                                    end
                                    else
                                        next_state = PGERS_ERROR;
                                end
                                else if ((TopBoot && !BottomBoot  && sect >= 255) ||
                                        (!TopBoot && BottomBoot && sect <= 32) ||
                                        (TopBoot && BottomBoot && (
                                         sect <= 16 || sect >= 271)))
                                begin
                                    if (Sec_ProtSE == 33 && ASP_ProtSE == 33)
                                    //Sector erase command is applied to a
                                    //256 KB range that includes 4 KB sectors.
                                    begin
                                        if (~CFR3V[5])
                                            next_state = SECTOR_ERS;
                                        else
                                            next_state = BLANK_CHECK;
                                    end
                                    else
                                        next_state = PGERS_ERROR;
                                end
                            end
                            else if ((Instruct == ERO04_C_0 || Instruct == ERO04_4_0) && WRPGEN == 1)  //Debug
                            begin
                                ReturnSectorID(sect,Address);

								#1;

								if (Sec_Prot[sect]== 0 && PPB_bits[sect]== 1 && DYB_bits[sect]== 1)
								begin

									if (!CFR3V[5]|| (CFR3V[5] && NOT_BLANK))
									begin
										next_state = SECTOR_ERS;
									end
									else
										next_state = IDLE;
								end
								else
									next_state = PGERS_ERROR;
                                //end
                            end
							else if ((Instruct == ERO32_C_0 || Instruct == ERO32_4_0) && WRPGEN)
							begin
								Address_erase_ns = Address - Address%16'h8000; //Align to half block. Only works for uniform section

								#1;

								for (i=0; i<8; i=i+1)
								begin
									Address_erase_ns = Address + i*(SecSize256 + 1);
									ReturnSectorID(sect,Address_erase_ns);

									if (Sec_Prot[sect]==1 || PPB_bits[sect]==0 || DYB_bits[sect]==0)
									begin
										next_state = PGERS_ERROR;
									end
								end

								if (next_state != PGERS_ERROR)
								begin
									if (!CFR3V[5]|| (CFR3V[5] && NOT_BLANK)) next_state = HALF_BLK_ERS;
									else		   							 next_state = IDLE;
								end
							end
							else if ((Instruct == ERO64_C_0 || Instruct == ERO64_4_0) && WRPGEN)
							begin
								Address_erase_ns = Address - Address%17'h10000; //Align to block. Only works for uniform section

								#1;

								for (i=0; i<16; i=i+1)
								begin
									Address_erase_ns = Address + i*(SecSize256 + 1);
									ReturnSectorID(sect,Address_erase_ns);

									if (Sec_Prot[sect]==1 || PPB_bits[sect]==0 || DYB_bits[sect]==0)
									begin
										next_state = PGERS_ERROR;
									end
								end

								if (next_state != PGERS_ERROR)
								begin
									if (!CFR3V[5] || (CFR3V[5] && NOT_BLANK)) next_state = BLK_ERS;
									else		  							  next_state = IDLE;
								end
							end
                            else if ((Instruct == ERCHP_0_0_60 || Instruct == ERCHP_0_0_C7) && WRPGEN == 1 &&
                                    (STR1V[4]==0 && STR1V[3]==0 && STR1V[2]==0))
                            begin
                                if (!CFR3V[5] || (CFR3V[5] && NOT_BLANK))
                                    next_state = BULK_ERS;
                                else
                                    next_state = IDLE;
                            end
                            else if ((Instruct == PRPPB_4_0 || Instruct == PRPPB_C_0) && WRPGEN)
                                if (ASPPPB && PPBLCK && ASPPRM)
                                    next_state = PPB_PG;
                                else
                                    next_state = PGERS_ERROR;
                            else if (Instruct == ERPPB_0_0 && WRPGEN)
                                if (ASPPPB && PPBLCK && ASPPRM)
                                    next_state = PPB_ERS;
                                else
                                    next_state = PGERS_ERROR;
                            else if ((Instruct == WRPLB_0_0) && WRPGEN == 1)
                                next_state = PLB_PG;
                            else if ((Instruct == WRDYB_4_1 || Instruct == WRDYB_C_1) && WRPGEN)
                            begin
                                if (DYAV_in == 8'hFF || DYAV_in == 8'h00)
                                    next_state = DYB_PG;
                                else
                                    next_state = PGERS_ERROR;
                            end
							else if ((Instruct == PGPWD_0_1) && WRPGEN)
                            begin
                                if (ASPPWD && ASPPER)
                                    next_state = PASS_PG;
                                else
                                    next_state = PGERS_ERROR;
                            end
						    else if ((Instruct == PRASP_0_1) && WRPGEN)
                            begin
                                if (ASPPWD && ASPPER)
                                    next_state = ASP_PG;
                                else
                                    next_state = PGERS_ERROR;
                            end
                            else if (Instruct == PWDUL_0_1 && ~RDYBSY)
                                next_state = PASS_UNLOCK;
							else if (Instruct == EN4BA_0_0)
								CFR2V[7] = 1;
							else if (Instruct == EX4BA_0_0)
								CFR2V[7] = 0;
                            else if (Instruct == EVERS_C_0)
                                next_state = EVAL_ERS_STAT;
                            else if (Instruct == DICHK_C_1)
                            begin
								/*if (QPI_IT && {quad_data_in[0],quad_data_in[1],quad_data_in[2],quad_data_in[3],quad_data_in[4],
											   quad_data_in[5],quad_data_in[6],quad_data_in[7]} >= (CRC_Start_Addr_reg + 3) ||
									!QPI_IT && {Data_in[7:0],Data_in[15:8],Data_in[23:16],Data_in[31:24]} >= (CRC_Start_Addr_reg + 3)
								   )*/
                                //if (Address >= CRC_Start_Addr_reg + 3)
                                // Condition for entering CRC_calc state is not complete
                                // it needs to have comparison of Addr to EndAddr
                                // Check datasheet for table of state transitions
								if (CRC_End_Addr_reg >= (CRC_Start_Addr_reg + 3))
                                    next_state = CRC_Calc;
                                else
                                    next_state = IDLE;
                            end
                            else if (Instruct == SPEPD_0_0)
                                next_state = CRC_SUSP;
                            // Reading Sector Erase Count register
                            else if (Instruct == SEERC_C_0 && !RDYBSY)
                            begin
                                //ReturnSectorID(sect,Address);
                                next_state = SEERC;
                            end
                            else
                                next_state = IDLE;
                        end
                        else if (DPD_entered)
                            next_state = DP_DOWN;
                    end
                    
                    AUTOBOOT :
                    begin
                        if (rising_edge_CSNeg_ipd)
                            next_state = IDLE;
                    end

					WRITE_ALL_REG :
					begin
						if (rising_edge_WDONE || rising_edge_CSDONE)
							next_state = IDLE;
					end

                    WRITE_ANY_REG :
                    begin
                        if (rising_edge_WDONE || rising_edge_CSDONE)
                            next_state = IDLE;
                    end

                    PAGE_PG :
                    begin
                        if (PRGSUSP_out_event && PRGSUSP_out == 1)
                            next_state = PG_SUSP;
                        else if (rising_edge_PDONE)
                            next_state = IDLE;
                    end

                    OTP_PG :
                    begin
                        if (rising_edge_PDONE)
                            next_state = IDLE;
                    end

                    PG_SUSP :
                    begin
                        if (falling_edge_write)
                        begin
                            if (Instruct == RSEPD_0_0)
                                next_state = PAGE_PG;
                        end
                    end

                    CRC_Calc :
                    begin
                        if ((Instruct == SPEPD_0_0) || rising_edge_START_T1_in)
                            next_state = CRC_SUSP;
                        if (rising_edge_CRCDONE)
                            next_state = IDLE;
                    end

                    CRC_SUSP :
                    begin
                        if (falling_edge_write)
                        begin
                            if (Instruct == RSEPD_0_0)
                                next_state = CRC_Calc;
                            else if (Instruct == SFRST_0_0)
                                next_state = RESET_STATE;
                        end
                    end

                    SECTOR_ERS :
                    begin
                        if (ERSSUSP_out_event && ERSSUSP_out == 1)
                            next_state = ERS_SUSP;
                        else if (rising_edge_EDONE)
                            next_state = IDLE;
                    end

                    HALF_BLK_ERS, BLK_ERS, BULK_ERS :
                    begin
                        if (rising_edge_EDONE)
                            next_state = IDLE;
                    end

                    ERS_SUSP :
                    begin
                        if (falling_edge_write)
                        begin
                            if ((Instruct==PRPGE_4_1 || Instruct==PRPGE_C_1 || Instruct==PRPG2_C_1 || Instruct==PRPG2_4_1 || Instruct==PRPG3_C_1 || Instruct==PRPG3_4_1)
								&& WRPGEN && ~PRGERR && crc_pass_cmd && crc_pass_pgm)
                            begin
                                ReturnSectorID(sect,Address);

                                if (SectorSuspend != Address/(SecSize256+1))
                                begin
                                    if (Sec_Prot[sect]== 0 && PPB_bits[sect]== 1 &&
                                        DYB_bits[sect]== 1)
                                    begin
                                        next_state = ERS_SUSP_PG;
                                    end
                                end
                            end
                            else if ((Instruct == WRDYB_4_1 || Instruct == WRDYB_C_1) && WRPGEN && ~PRGERR)
                            begin
                                if (DYAV_in == 8'hFF || DYAV_in == 8'h00)
                                    next_state = DYB_PG;
                                else
                                    next_state = PGERS_ERROR;
                            end
                            else if ((Instruct == RSEPD_0_0) && ~PRGERR)
                                next_state = SECTOR_ERS;
                        end
                    end

                    ERS_SUSP_PG :
                    begin
                        if (rising_edge_PDONE)
                            next_state = ERS_SUSP;
                        else if (PRGSUSP_out_event && PRGSUSP_out == 1)
                            next_state = ERS_SUSP_PG_SUSP;
                    end

                    ERS_SUSP_PG_SUSP :
                    begin

                        if (falling_edge_write)
                        begin
                            if (Instruct == RSEPD_0_0)
                            begin
                                next_state = ERS_SUSP_PG;
                            end
                        end
                    end

                    PASS_PG :
                    begin
                        if (rising_edge_PDONE)
                            next_state = IDLE;
                    end

                    PASS_UNLOCK :
                    begin
                        if (falling_edge_PASSULCK_in)
                        begin
                            if (~PRGERR)
                                next_state = IDLE;
                            else
                                next_state = PGERS_ERROR;
                        end
                    end

                    PPB_PG :
                    begin
                        if (rising_edge_PDONE)
                            next_state = IDLE;
                    end

                    PPB_ERS :
                    begin
                    if (falling_edge_PPBERASE_in)
                        next_state = IDLE;
                    end

                    PLB_PG :
                    begin
                    if (rising_edge_PDONE)
                        next_state = IDLE;
                    end

                    DYB_PG :
                    begin
                    if (rising_edge_PDONE)
                        if (ERASES)
                            next_state = ERS_SUSP;
                        else
                            next_state = IDLE;
                    end

                    ASP_PG :
                    begin
                    if (rising_edge_PDONE)
                        next_state = IDLE;
                    end

                    PGERS_ERROR :
                    begin
                        if (falling_edge_write)
                        begin
                            if (Instruct == WRDIS_0_0 && ~PRGERR && ~ERSERR)
                            begin
                            // A Clear Status Register (CLPEF_0_0) followed by a Write
                            // Disable (WRDIS_0_0) command must be sent to return the
                            // device to standby state
                                next_state = IDLE;
                            end
                        end
                    end

                    /*BLANK_CHECK :
                    begin
                        if (rising_edge_BCDONE)
                        begin
                            if (NOT_BLANK)
                                if (Instruct == ERCHP_0_0_60 || Instruct == ERCHP_0_0_C7)
                                    next_state = BULK_ERS;
								else if (Instruct == ERO32_4_0 || Instruct == ERO32_C_0)
									next_state = HALF_BLK_ERS;
								else if (Instruct == ERO64_4_0 || Instruct == ERO64_C_0)
									next_state = BLK_ERS;
                                else
                                    next_state = SECTOR_ERS;
                            else
                                next_state = IDLE;
                        end
                    end*/

                    EVAL_ERS_STAT :
                    begin
                        if (rising_edge_EESDONE)
                            next_state = IDLE;
                    end

                    DP_DOWN:
                    begin
                        if (falling_edge_RST && CFR4N[2] == 1'b0)
                            next_state = RESET_STATE;
                        else if (rising_edge_DPD_out)
                            next_state = IDLE;
                    end

                    SEERC :
                    begin
                        if (rising_edge_SEERC_DONE)
                            next_state = IDLE;
                    end

                endcase
            end
        end
    end

//    /////////////////////////////////////////////////////////////////////////
//    //FSM Output generation and general functionality
//    /////////////////////////////////////////////////////////////////////////
    reg change_addr_event    = 1'b0;
    reg Instruct_event       = 1'b0;
    reg current_state_event  = 1'b0;

    integer WData [0:511];
    integer WOTPData;
    integer Addr;
    integer Addr_tmp;
    integer Addr_idcfi;

    always @(Instruct_event)
    begin
        read_cnt  = 0;
        byte_cnt  = 1;
        rd_fast   = 1'b0;
        rd_slow   = 1'b0;
        dual      = 1'b0;
        ddr       = 1'b0;
        any_read  = 1'b0;
        Addr_idcfi  = 0;
    end

    always @(posedge read_out)
    begin
        if (PoweredUp == 1'b1)
        begin
            oe_z = 1'b1;
            #1000 oe_z = 1'b0;

            if (CSNeg_ipd==1'b0)
            begin
                oe = 1'b1;
                #1000 oe = 1'b0;
            end
        end
    end

    always @(change_addr_event)
    begin
        if (change_addr_event)
        begin
            read_addr = Address;
        end
    end

    always @(posedge PASSACC_out)
    begin
//         STR1V[0] = 1'b0; //RDYBSY
        PASSACC_in = 1'b0;
    end

    always @(rising_edge_PoweredUp or posedge oe or posedge oe_z or rising_edge_CRCDONE or
           posedge WDONE or posedge CSDONE or posedge PDONE or posedge EDONE or falling_edge_RST or
           current_state_event or posedge PRGSUSP_out or posedge ERSSUSP_out or
           posedge PASSULCK_out or posedge PPBERASE_out or rising_edge_BCDONE or
           rising_edge_EESDONE or falling_edge_write or rising_edge_DPD_out or
           posedge start_autoboot or Instruct or Address or INC0V or
           rising_edge_CSNeg_ipd or rising_edge_reseted or change_addr_event or
           posedge SEERC_DONE or DPD_in or DPDExt_out or rising_edge_DPD_POR_out)
    begin: Functionality
    integer i,j;
    integer sect;

        if (rising_edge_PoweredUp)
        begin
            // the default condition after power-up
            // During POR,the non-volatile version of the registers is copied to
            // volatile version to provide the default state of the volatile
            // register
            STR1V[4:2] = STR1N[4:2];
            STR1V[7:5] = STR1N[7:5];
            STR1V[1:0] = STR1N[1:0];

            CFR1V = CFR1N;
            CFR2V = CFR2N;
            CFR3V = CFR3N;
            CFR4V = CFR4N;
            CFR5V = CFR5N;

            ICRV = 32'hFFFFFFFF;
            icrc_out = 32'hFFFFFFFF;
            icrc_cnt = 0;
            INTNeg_zd    = 1'b1;
            INC0V = 8'hFF;
            INS0V = 8'hFF;

            //As shipped from the factory, all devices default ASP to the
            //Persistent Protection mode, with all sectors unprotected,
            //when power is applied. The device programmer or host system must
            //then choose which sector protection method to use.
            //For Persistent Protection mode, PPBLOCK defaults to "1"
            PPLV[0] = 1'b1;
            
            if (ASPDYB)
                DYAV[7:0] = 8'hFF;
            else
                DYAV[7:0] = 8'h00;

            if (~ASPDYB)
                //All the DYB power-up in the protected state
                DYB_bits = {8192{1'b0}};
            else
                //All the DYB power-up in the unprotected state
                DYB_bits = {8192{1'b1}};

            BP_bits = {STR1V[4],STR1V[3],STR1V[2]};
            change_BP = 1'b1;
            #1 change_BP = 1'b0;

            CRC_ACT = 1'b0;
            CRC_RD_SETUP = 1'b0;
        end

        if (rising_edge_DPD_out)
        begin
            DPD_in        = 1'b0;
            DPD_entered   = 1'b0;
            DPDExt_out    = 1'b0;
            ICRV = 32'hFFFFFFFF;
            icrc_out = 32'hFFFFFFFF;
            icrc_cnt = 0;
            INTNeg_zd       = 1'b1;
            INC0V = 8'hFF;
            INS0V = 8'hFF; //???
            STR1V[1] = 0;
        end

        case (current_state)
            IDLE :
            begin


                ASP_ProtSE = 0;
                Sec_ProtSE = 0;

                if (BottomBoot == 1'b1 && TopBoot == 1'b0)
                begin
                    for (j=32;j>=0;j=j-1)
                    begin
                        if (PPB_bits[j] == 1 && DYB_bits[j] == 1)
                        begin
                            ASP_ProtSE = ASP_ProtSE + 1;
                        end
                        if (Sec_Prot[j] == 0)
                        begin
                            Sec_ProtSE = Sec_ProtSE + 1;
                        end
                    end
                end
                else if (BottomBoot == 1'b0 && TopBoot == 1'b1)
                begin
                    for (j=287;j>=255;j=j-1)
                    begin
                        if (PPB_bits[j] == 1 && DYB_bits[j] == 1)
                        begin
                            ASP_ProtSE = ASP_ProtSE + 1;
                        end
                        if (Sec_Prot[j] == 0)
                        begin
                            Sec_ProtSE = Sec_ProtSE + 1;
                        end
                    end
                end
                else if (BottomBoot == 1'b1 && TopBoot == 1'b1)
                begin
                    for (j=16;j>=0;j=j-1)
                    begin
                        if (PPB_bits[j] == 1 && DYB_bits[j] == 1)
                        begin
                            ASP_ProtSE = ASP_ProtSE + 1;
                        end
                        if (Sec_Prot[j] == 0)
                        begin
                            Sec_ProtSE = Sec_ProtSE + 1;
                        end
                    end
                    for (j=287;j>=271;j=j-1)
                    begin
                        if (PPB_bits[j] == 1 && DYB_bits[j] == 1)
                        begin
                            ASP_ProtSE = ASP_ProtSE + 1;
                        end
                        if (Sec_Prot[j] == 0)
                        begin
                            Sec_ProtSE = Sec_ProtSE + 1;
                        end
                    end
                    Sec_ProtSE = Sec_ProtSE - 1;
                    ASP_ProtSE = ASP_ProtSE - 1;
                end

                if (falling_edge_write && (DPD_in == 1'b0))
                begin
					if ((ITCRCE && crc_pass_cmd) || !ITCRCE)
					begin
						if (Instruct == WRENB_0_0 || Instruct == WRENV_0_0)
						begin
							STR1V[1] = 1'b1;
						end else if (Instruct == WRDIS_0_0)
						begin
							STR1V[1] = 1'b0;
						end
					end

                    if (Instruct == EVERS_C_0)
                    begin
                        ReturnSectorID(sect,Address);

                        EESSTART = 1'b1;
                        EESSTART <= #5 1'b0;
                        STR1V[0] = 1'b1;  // RDYBSY
                        //STR1V[1] = 1'b1;  // WRPGEN
                    end
					else if (Instruct == WRREG_0_1)
					begin
						CSSTART = 1'b1;
                        CSSTART <= #5 1'b0;
                        STR1V[0] = 1'b1;  // RDYBSY
					end
                    else if (((Instruct == WRARG_C_1 && WRPGEN == 1) && crc_pass_cmd && ITCRCE) ||
					         ((Instruct == WRARG_C_1 && WRPGEN == 1) && !ITCRCE))
                    begin
                        // can not execute if WRPGEN bit is zero or Hardware
                        // Protection Mode is entered and SR1NV,SR1V,CR1NV or
                        // CR1V is selected (no error is set)
                        Addr = Address;

                        if ((Address == 32'h00000001)  ||
                            ((Address >  32'h00000006)  &&
                            (Address <  32'h00000010)) ||
                            ((Address >  32'h00000011)  &&
                            (Address <  32'h00000020)) ||
                            ((Address >  32'h00000027)  &&
                            (Address <  32'h00000030)) ||
                            ((Address >  32'h00000031)  &&
                                    (Address <  32'h00000042)) ||
                                   ((Address >  32'h00000045)  &&
                                    (Address <  32'h00800000)) ||
                            ((Address >  32'h00800006) &&
                            (Address <  32'h00800008)) ||
                            ((Address >  32'h00800008) &&
                            (Address <  32'h00800010)) ||
                            ((Address >  32'h00800011) &&
                            (Address <  32'h00800067)) ||
                            (Address >  32'h00800068)
                            )
                        begin
                            STR1V[1] = 1'b0; // WRPGEN
                        end
                        else if ((Address == 32'h00000002) &&
                               ((PLPROT_O == 1'b1 && WRAR_reg_in[4] == 1'b0) ))
                        begin
                            STR1V[1] = 1'b0; // WRPGEN
                        end
                        else if ((~(ASPPWD && ASPPER)) &&
                                (Address == 32'h00000030  || // ASPR[7:0]
                                Address == 32'h00000031))   // ASPR[15:8]
                        begin
                                STR1V[6] = 1'b1; // PRGERR
                                STR1V[0] = 1'b1; // RDYBSY
                        end
                        else if ((~( ASPPER)) && (
                                Address == 32'h00000020  || // PASS[7:0]
                                Address == 32'h00000021  || // PASS[15:8]
                                Address == 32'h00000022  || // PASS[23:16]
                                Address == 32'h00000023  || // PASS[31:24]
                                Address == 32'h00000024  || // PASS[39:32]
                                Address == 32'h00000025  || // PASS[47:40]
                                Address == 32'h00000026  || // PASS[55:48]
                                Address == 32'h00000027  || // PASS[63:56]
                                Address == 32'h00000030  || // ASPR[7:0]
                                Address == 32'h00000031  //||
								//((WRAR_reg_in[6] == 1'b1 || WRAR_reg_in[5] == 1'b1 || WRAR_reg_in[4] == 1'b1 || WRAR_reg_in[2] == 1'b1 ) && Address == 32'h00000002) || // CR1NV
                                //(WRAR_reg_in[3] == 1'b1 && Address == 32'h00000004)
                               ))								
                        begin
                                STR1V[6] = 1'b1; // PRGERR
                                STR1V[0] = 1'b1; // RDYBSY
                        end
                        else // Protection Mode not selected
                        begin
                            if ((Address == 32'h00000030) ||
                                (Address == 32'h00000031))//ASPR
                            begin
                                if (WRAR_reg_in[2] == 1'b0 &&
                                    WRAR_reg_in[1] == 1'b0 &&
                                    Address == 32'h00000030)
                                begin
                                    STR1V[6] = 1'b1; // PRGERR
                                    STR1V[0] = 1'b1; // RDYBSY
                                end
                                else
                                begin
                                    WSTART = 1'b1;
                                    WSTART <= #5 1'b0;
                                    STR1V[0] = 1'b1;  // RDYBSY
                                end
                            end
                            else if ((Address == 32'h00000000) ||
                                        (Address == 32'h00000010) ||
                                        (Address >= 32'h00000002) &&
                                        (Address <= 32'h00000006) ||
                                        (Address >= 32'h00000020) &&
                                        (Address <= 32'h00000027) ||
                                        (Address == 32'h00000042) ||
                                        (Address == 32'h00000043) ||
                                        (Address == 32'h00000044) ||
                                        (Address == 32'h00000045) )
                            begin
                                WSTART = 1'b1;
                                WSTART <= #5 1'b0;
                                STR1V[0] = 1'b1;  // RDYBSY
                            end
                            else
                            begin
                                CSSTART = 1'b1;
                                CSSTART <= #5 1'b0;
                                STR1V[0] = 1'b1;  // RDYBSY
                            end
                        end
                    end
                    else if (
							 ((Instruct == PRPGE_4_1 || Instruct == PRPGE_C_1) ||
							  (Instruct == PRPG2_C_1 || Instruct == PRPG2_4_1) ||
							  (Instruct == PRPG3_C_1 || Instruct == PRPG3_4_1))
							  && WRPGEN ==1 && crc_pass_pgm && crc_pass_cmd
							)
                    begin
                        ReturnSectorID(sect,Address);
                        pgm_page = Address / (PageSize+1);

                        if (Sec_Prot[sect] == 0 &&
                            PPB_bits[sect]== 1 && DYB_bits[sect]== 1)
                        begin
                            PSTART  = 1'b1;
                            PSTART <= #5 1'b0;
                            PGSUSP  = 0;
                            PGRES   = 0;
                            INITIAL_CONFIG = 1;
                            STR1V[0] = 1'b1;  // RDYBSY
                            Addr    = Address;
                            Addr_tmp= Address;
                            wr_cnt  = Byte_number;
                            for (i=wr_cnt;i>=0;i=i-1)
							//for (i=(wr_cnt-1);i>=0;i=i-1)
                            begin
                                if (Viol != 0)
                                    WData[i] = -1;
                                else
                                    WData[i] = WByte[i];
                            end
                        end
                        else
                        begin
                        //PRGERR bit will be set when the user attempts to
                        //to program within a protected main memory sector
                            STR1V[6] = 1'b1; //PRGERR
                            STR1V[0] = 1'b1; //RDYBSY
                        end
                    end
                    else if (Instruct == PRSSR_C_1 && WRPGEN == 1)
                    begin
                        if (Address + Byte_number <= OTPHiAddr)
                        begin //Program within valid OTP Range
                            if (((((Address>=16'h0010 && Address<=16'h00FF))
                                && LOCK_BYTE1[Address/32] == 1) ||
                                ((Address>=16'h0100 && Address<=16'h01FF)
                                && LOCK_BYTE2[(Address-16'h0100)/32]==1) ||
                                ((Address>=16'h0200 && Address<=16'h02FF)
                                && LOCK_BYTE3[(Address-16'h0200)/32]==1) ||
                                ((Address>=16'h0300 && Address<=16'h03FF)
                                && LOCK_BYTE4[(Address-16'h0300)/32] == 1)))
                            begin
                            //rev N, TLPROT no longer protects SSR region(OTP)
                            // As long as the TLPROT bit remains cleared to a
                            // logic '0' the OTP address space is programmable.
//                                 if (TLPROT == 0)
//                                 begin
                                    PSTART  = 1'b1;
                                    PSTART <= #5 1'b0;
                                    STR1V[0] = 1'b1; //RDYBSY
                                    Addr    = Address;
                                    Addr_tmp= Address;
                                    wr_cnt  = Byte_number;
                                    for (i=wr_cnt;i>=0;i=i-1)
                                    begin
                                        if (Viol != 0)
                                            WData[i] = -1;
                                        else
                                            WData[i] = WByte[i];
                                    end
//                                 end
//                                 else
                                //rev N, TLPROT no longer protects SSR region(OTP)
                                //Attempting to program within valid OTP
                                //range while TLPROT = 1
//                                 begin
//                                     STR1V[6] = 1'b1; // PRGERR
//                                     STR1V[0] = 1'b1; // RDYBSY
//                                 end
                            end
                            else if (ZERO_DETECTED)
                            begin
                                if (Address > 12'h3FF)
                                begin
                                    $display ("Given address is ");
                                    $display ("out of OTP address range");
                                end
                                else
                                begin
                                //Attempting to program any zero in the 16
                                //lowest bytes or attempting to program any zero
                                //in locked region
                                    STR1V[6] = 1'b1; // PRGERR
                                    STR1V[0] = 1'b1; // RDYBSY
                                end
                            end
                        end
                    end
                    else if ((Instruct==ER256_4_0) && WRPGEN == 1)
                    begin
                        ReturnSectorID(sect,Address);
                        SectorErased  = sect;
                        SectorSuspend = Address/(SecSize256+1);

                        if (UniformSec || (TopBoot && !BottomBoot  && sect <= 255) ||
                           (!TopBoot && BottomBoot && sect >= 32) || (TopBoot && BottomBoot
                                && (sect >=16 && sect <= 271)))
                        begin

                            if (Sec_Prot[sect]== 0 && PPB_bits[sect]== 1
                                 && DYB_bits[sect]== 1)
                            begin
                                Addr = Address;
                                if (~CFR3V[5])
                                begin
                                    bc_done = 1'b0;
                                    ESTART  = 1'b1;
                                    ESTART <= #5 1'b0;
                                    ESUSP     = 0;
                                    ERES      = 0;
                                    INITIAL_CONFIG = 1;
                                    STR1V[0] = 1'b1; //RDYBSY
                                end
                            end
                            else
                            begin
                            //ERSERR bit will be set when the user attempts to
                            //erase an individual protected main memory sector
                                STR1V[5] = 1'b1; //ERSERR
                                STR1V[0] = 1'b1; //RDYBSY
                            end
                        end
                        else if ((TopBoot && !BottomBoot  && sect >= 255) ||
                                (!TopBoot && BottomBoot && sect <= 32) ||
                                (TopBoot && BottomBoot
                                && (sect <= 16 || sect >= 271)))
                        begin
                            if (Sec_ProtSE == 33 && ASP_ProtSE == 33)
                            //Sector erase command is applied to a
                            //256 KB range that includes 4 KB sectors.
                            begin
                                Addr = Address;
                                if (~CFR3V[5])
                                begin
                                    bc_done = 1'b0;
                                    ESTART = 1'b1;
                                    ESTART <= #5 1'b0;
                                    ESUSP     = 0;
                                    ERES      = 0;
                                    INITIAL_CONFIG = 1;
                                    STR1V[0] = 1'b1; //RDYBSY
                                end
                            end
                            else
                            begin
                            //ERSERR bit will be set when the user attempts to
                            //erase an individual protected main memory sector
                                STR1V[5] = 1'b1; //ERSERR
                                STR1V[0] = 1'b1; //RDYBSY
                            end
                        end
                    end
                    else if ((Instruct == ERO04_C_0 || Instruct == ERO04_4_0) && WRPGEN == 1)
                    begin
                        ReturnSectorID(sect,Address);

                        if (Sec_Prot[sect] == 0 && PPB_bits[sect]== 1 && DYB_bits[sect]== 1 && ((ITCRCE && crc_pass_cmd) || ~ITCRCE))
                         //A P4E instruction applied to a sector
                         //that has been Write Protected through the
                         //Block Protect Bits or ASP will not be
                         //executed and will set the ERSERR status
                         begin
                             Address_erase = Address - Address%16'h1000; //align to sector

							 if (CFR3V[5])
							 begin
							 	for (j=Address_erase; j<(Address_erase+4096); j=j+1)
								begin
							 		memory_features_i0.read_mem_w(
										mem_data,
										j
									);

									if (mem_data != 8'hFF) NOT_BLANK = 1'b1;
								end
							 end

                             if (!CFR3V[5] || (CFR3V[5] && NOT_BLANK))
                             begin
                                 bc_done = 1'b0;
                                 ESTART = 1'b1;
                                 ESTART <= #5 1'b0;
                                 ESUSP     = 0;
                                 ERES      = 0;
                                 INITIAL_CONFIG = 1;
                                 STR1V[0] = 1'b1; //RDYBSY
                             end							 
                         end
                         else
                         begin
                         //ERSERR bit will be set when the user attempts to
                         //erase an individual protected main memory sector
                             STR1V[5] = 1'b1; //ERSERR
                             STR1V[0] = 1'b1; //RDYBSY
                         end
                    end
					else if ((Instruct == ERO32_C_0 || Instruct == ERO32_4_0) && WRPGEN == 1)
					begin
						Address_erase = Address - Address%16'h8000; //align to half block. Only works for uniform section
						half_block_erase_is_allowed = 1;

						for (j=0; j<8; j=j+1)
						begin
							Address_erase = Address + j*(SecSize256 + 1);
							ReturnSectorID(sect,Address_erase);

							if (Sec_Prot[sect]==1 || PPB_bits[sect]==0 || DYB_bits[sect]==0 && ((ITCRCE && crc_pass_cmd) || ~ITCRCE))
							begin
								half_block_erase_is_allowed = 0;

								//ERSERR bit will be set when the user attempts to
                         		//erase an individual protected main memory sector
                             	STR1V[5] = 1'b1; //ERSERR
                             	STR1V[0] = 1'b1; //RDYBSY
							end
						end

						if (half_block_erase_is_allowed)
						begin
							Address_erase = Address - Address%16'h8000; //align to half block. Only works for uniform section

							if (CFR3V[5])
							begin
								for (i=Address_erase; i<(Address_erase+16'h8000); i=i+1)
								begin
									memory_features_i0.read_mem_w(
										mem_data,
										//(Address_erase+i)
										i
									);

									if (mem_data != 8'hFF) NOT_BLANK = 1'b1;
								end
							end

							if (!CFR3V[5] || (CFR3V[5] && NOT_BLANK))
							begin
								bc_done = 1'b0;
								ESTART = 1'b1;
								ESTART <= #5 1'b0;
								ESUSP = 0;
								ERES = 0;
								INITIAL_CONFIG = 1;
								STR1V[0] = 1'b1;
							end
						end
					end
					else if ((Instruct == ERO64_C_0 || Instruct == ERO64_4_0) && WRPGEN == 1)
					begin
						Address_erase = Address - Address%17'h10000; //align to block. Only works for uniform section
						block_erase_is_allowed = 1;

						for (j=0; j<16; j=j+1)
						begin
							Address_erase = Address + j*(SecSize256 + 1);
							ReturnSectorID(sect,Address_erase);

							if (Sec_Prot[sect]==1 || PPB_bits[sect]==0 || DYB_bits[sect]==0 && ((ITCRCE && crc_pass_cmd) || ~ITCRCE))
							begin
								block_erase_is_allowed = 0;

								//ERSERR bit will be set when the user attempts to
                         		//erase an individual protected main memory sector
                             	STR1V[5] = 1'b1; //ERSERR
                             	STR1V[0] = 1'b1; //RDYBSY
							end
						end

						if (block_erase_is_allowed)
						begin
							Address_erase = Address - Address%17'h10000; //align to half block. Only works for uniform section

							if (CFR3V[5])
							begin
								for (i=Address_erase; i<(Address_erase+17'h10000); i=i+1)
								begin
									memory_features_i0.read_mem_w(
										mem_data,
										i
									);

									if (mem_data != 8'hFF) NOT_BLANK = 1'b1;
								end
							end

							if (!CFR3V[5] || (CFR3V[5] && NOT_BLANK))
							begin
								bc_done = 1'b0;
								ESTART = 1'b1;
								ESTART <= #5 1'b0;
								ESUSP = 0;
								ERES = 0;
								INITIAL_CONFIG = 1;
								STR1V[0] = 1'b1;
							end
						end
					end
                    else if ((Instruct == ERCHP_0_0_60 || Instruct == ERCHP_0_0_C7) && WRPGEN == 1)
                    begin
						if (CFR3V[5])
						begin
							for (i=0; i<((SecNumUni+1)*(SecSize256+1)); i=i+1)
							begin
								memory_features_i0.read_mem_w(
									mem_data,
									i
								);

								if (mem_data != 8'hFF) NOT_BLANK = 1'b1;
							end
						end
						

                        if (STR1V[4]==0 && STR1V[3]==0 && STR1V[2]==0 && ((ITCRCE && crc_pass_cmd) || ~ITCRCE))
                        begin
                            if (!CFR3V[5] || (CFR3V[5] && NOT_BLANK))
                            begin
                                bc_done = 1'b0;
                                ESTART = 1'b1;
                                ESTART <= #5 1'b0;
                                ESUSP  = 0;
                                ERES   = 0;
                                INITIAL_CONFIG = 1;
                                STR1V[0] = 1'b1; //RDYBSY
                            end
                        end
                        else
                        begin
                        //The Bulk Erase command will not set ERSERR if a
                        //protected sector is found during the command
                        //execution.
                            STR1V[1] = 1'b0;//WRPGEN
                        end
                    end
                    else if ((Instruct == PRPPB_4_0 || Instruct == PRPPB_C_0) && WRPGEN)
                    begin
                        if (ASPPPB && PPBLCK && ASPPRM)
                        begin
                            ReturnSectorID(sect,Address);
                            PSTART = 1'b1;
                            PSTART <= #5 1'b0;
                            STR1V[0] = 1'b1;//RDYBSY
                        end
                        else
                        begin
                            STR1V[6] = 1'b1; // PRGERR
                            STR1V[0] = 1'b1; // RDYBSY
                        end
                    end
                    else if (Instruct == ERPPB_0_0 && WRPGEN)
                    begin
                            if (ASPPPB && PPBLCK && ASPPRM)
                            begin
                                PPBERASE_in = 1'b1;
                                STR1V[0] = 1'b1; // RDYBSY
                            end
                            else
                            begin
                                STR1V[5] = 1'b1; // ERSERR
                                STR1V[0] = 1'b1; // RDYBSY
                            end
//                             STR1V[1] = 1'b0; // WRPGEN ?? secure_opN
                    end
                    else if ((Instruct == WRPLB_0_0) && WRPGEN == 1)
                    begin
                        PSTART = 1'b1;
                        PSTART <= #5 1'b0;
                        STR1V[0] = 1'b1; // RDYBSY
                    end
                    else if ((Instruct == WRDYB_4_1 || Instruct == WRDYB_C_1) && WRPGEN)
                    begin
                        if (DYAV_in == 8'hFF || DYAV_in == 8'h00)
                        begin
                            ReturnSectorID(sect,Address);
                            PSTART   = 1'b1;
                            PSTART  <= #5 1'b0;
                            STR1V[0] = 1'b1;// RDYBSY
                        end
                        else
                        begin
                            STR1V[6] = 1'b1;// PRGERR
                            STR1V[0] = 1'b1;// RDYBSY
                        end
                    end										
					else if (Instruct == PGPWD_0_1 && WRPGEN)
                    begin
					    if(ASPPWD &&  ASPPER)
						begin
                            PSTART   = 1'b1;
                            PSTART  <= #5 1'b0;
                            STR1V[0] = 1'b1;// RDYBSY
						end
						else
						begin
						    STR1V[6] = 1'b1;// PRGERR
                            STR1V[0] = 1'b1;// RDYBSY
						end
                    end
					else if (Instruct == PRASP_0_1 && WRPGEN)
                    begin
					    if(ASPPWD &&  ASPPER)
						begin
                            PSTART   = 1'b1;
                            PSTART  <= #5 1'b0;
                            STR1V[0] = 1'b1;// RDYBSY
						end
						else
						begin
						    STR1V[6] = 1'b1;// PRGERR
                            STR1V[0] = 1'b1;// RDYBSY
						end
                    end					
                    else if (Instruct == PWDUL_0_1)
                    begin
                        if (~RDYBSY)
                        begin
                            PASSULCK_in = 1;
                            STR1V[0] = 1'b1; //RDYBSY
                        end
                        else
                        begin
                            $display ("The PWDUL_0_1 command cannot be accepted");
                            $display (" any faster than once every 100us");
                        end
                    end
                    else if (Instruct == DICHK_C_1)
                    begin
						if (QPI_IT)
						begin
							for (i=7;i>=0;i=i-1)
							begin
								CRC_Start_Addr_reg[(i+1)*4 - 1 -: 4] = quad_data_in[7-i];
								CRC_End_Addr_reg[(i+1)*4 - 1 -: 4]   = quad_data_in[15-i];
							end
						end
						else
						begin
							for (i=3;i>=0;i=i-1)
							begin
								CRC_Start_Addr_reg[(i+1)*8 - 1 -: 8] = Data_in[(4-i)*8 - 1 -: 8];
								CRC_End_Addr_reg[(i+1)*8 - 1 -: 8]   = Data_in[(8-i)*8 - 1 -: 8];
							end
						end

                        if (CRC_End_Addr_reg >= (CRC_Start_Addr_reg + 3))
                        begin
                            CRCSTART = 1'b1;
                            CRCSTART <= #5 1'b0;
                            STR1V[0] = 1'b1;
                            STR2V[3] = 1'b0; // DICRCA
                            DCRV  = 32'h00000000;
                        end
                        else
                        begin
                            // Abort CRC calculation
                            $display ("CRC EndAddr is not StartAddr+3 ");
                            $display ("or greater; CRC calculation is aborted");
                            STR2V[3] = 1'b1; // DICRCA
                        end
                    end
                    else if (Instruct == SPEPD_0_0 && ~START_T1_in)
                    begin
                        START_T1_in = 1'b1;
                    end
                    else if (Instruct == CLECC_0_0)
                    begin
                        ECSV[4] = 0;// 2 bits ECC detection
                        ECSV[3] = 0;// 1 bit ECC correction
                        INS0V[1] = 1;
                        INS0V[0] = 1;
                        ECTV = 16'h0000;
                        EATV = 32'h00000000;
                    end
                    else if (Instruct == CLPEF_0_0)
                    begin
                        STR1V[6] = 0;// PRGERR
                        STR1V[5] = 0;// ERSERR
                        STR1V[0] = 0;// RDYBSY
                    end
                    else if (Instruct == ENDPD_0_0)
                    begin
						if (!RDYBSY) DPD_in = 1'b1;
                    end
                    else if (Instruct == SEERC_C_0)
                    begin
                        //ReturnSectorID(sect,Address);
                        //SectorErased  = sect;
                        //SectorSuspend = Address/(SecSize256+1);

                        //Addr = Address;

						#3;

						Address_erase_cnt = Address;
						SectorSuspend = Address/(SecSize256+1);

                        SEERC_START  = 1'b1;
                        SEERC_START  <= #5 1'b0;

                        STR1V[0] = 1'b1; //RDYBSY
                    end

                    if (Instruct == SRSTE_0_0)
                    begin
                        RESET_EN = 1;
                    end
                    else
                    begin
                        RESET_EN <= 0;
                    end
                end
                else if (oe_z)
                begin
                    if ((Instruct == RDAY1_C_0) || (Instruct == RDAY2_C_0) ||
                    ((Instruct == RDAY1_4_0) && (~QPI_IT)))
                    begin
                        rd_fast = 1'b0;
                        rd_slow = 1'b1;
                        dual    = 1'b0;
                        ddr     = 1'b0;
                    end
                    else if ((Instruct == RDAY2_4_0) && QPI_IT && SDRDDR)
                    begin
                        rd_fast = 1'b0;
                        rd_slow = 1'b0;
                        dual    = 1'b1;
                        ddr     = 1'b1;
                    end
                    else
                    begin
                        rd_fast = 1'b1;
                        rd_slow = 1'b0;
                        dual    = 1'b0;
                        ddr     = 1'b0;
                    end
                end
                else if (oe)
                begin
                    any_read = 1'b1;
                    if (Instruct == RDSR1_0_0)
                    begin
                    //Read Status Register 1
                        if (QPI_IT)
                        begin
                            if      (read_cnt == 0)                     data_out[3:0] = STR1V[7:4];
							else if (read_cnt == 1)						data_out[3:0] = STR1V[3:0];
							else if (read_cnt == 2)						data_out[3:0] = ~STR1V[7:4];
							else if (read_cnt == 3)						data_out[3:0] = ~STR1V[3:0];
						
							DataDriveOut_Dout[1] = data_out[3];
							DataDriveOut_Dout[0] = data_out[2];
                            DataDriveOut_SO = data_out[1];
                            DataDriveOut_SI = data_out[0];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;

                            read_cnt = read_cnt + 1;

							if 		(ITCRCE && read_cnt == 4)  read_cnt = 0;
							else if (!ITCRCE && read_cnt == 2) read_cnt = 0;
						end
						else
                        begin
							if (ITCRCE && read_cnt >= 8) DataDriveOut_SO = ~STR1V[15-read_cnt];
                            else        				 DataDriveOut_SO = STR1V[7-read_cnt];

                            read_cnt = read_cnt + 1;

							if      (ITCRCE && read_cnt == 16) read_cnt = 0;
							else if (!ITCRCE && read_cnt == 8) read_cnt = 0;
                        end
                    end
                    else if (Instruct == RDSR2_0_0)
                    begin
                        //Read Status Register 2
                        if (QPI_IT)
                        begin
                            if      (read_cnt == 0)                     data_out[3:0] = STR2V[7:4];
							else if (read_cnt == 1)						data_out[3:0] = STR2V[3:0];
							else if (read_cnt == 2)						data_out[3:0] = ~STR2V[7:4];
							else if (read_cnt == 3)						data_out[3:0] = ~STR2V[3:0];
						
							DataDriveOut_Dout[1] = data_out[3];
							DataDriveOut_Dout[0] = data_out[2];
                            DataDriveOut_SO = data_out[1];
                            DataDriveOut_SI = data_out[0];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;

                            read_cnt = read_cnt + 1;

							if 		(ITCRCE && read_cnt == 4)  read_cnt = 0;
							else if (!ITCRCE && read_cnt == 2) read_cnt = 0;
						end
						else
                        begin
							if (ITCRCE && read_cnt >= 8) DataDriveOut_SO = ~STR2V[15-read_cnt];
                            else        				 DataDriveOut_SO = STR2V[7-read_cnt];

                            read_cnt = read_cnt + 1;

							if      (ITCRCE && read_cnt == 16) read_cnt = 0;
							else if (!ITCRCE && read_cnt == 8) read_cnt = 0;
                        end
                    end
                    else if (Instruct == RDARG_C_0)
                    begin
						READ_ALL_REG(Address, RDAR_reg);

                        if (QPI_IT)
                        begin
						    ->Mevl;
                            data_out_nibble[0]  = RDAR_reg[7:4];
							data_out_nibble[1]  = RDAR_reg[3:0];
							data_out_nibble[2]  = ~RDAR_reg[7:4];
							data_out_nibble[3]  = ~RDAR_reg[3:0];
							{DataDriveOut_Dout[1:0], DataDriveOut_SO, DataDriveOut_SI} = data_out_nibble[read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;

                            read_cnt = read_cnt + 1;							
							if ((ITCRCE && read_cnt == 4) || ~ITCRCE && (read_cnt == 2))
								 read_cnt = 0;	
                        end
                        else
                        begin
						    data_out[7:0]   = RDAR_reg;
							data_outb[7:0]  = ~RDAR_reg;
							if(read_cnt < 8)
							    DataDriveOut_SO = data_out[7-read_cnt];
							else if(read_cnt >= 8)
							    DataDriveOut_SO = data_outb[15-read_cnt];
							read_cnt = read_cnt + 1;
							if ((ITCRCE && read_cnt == 16) || ~ITCRCE && (read_cnt == 8))
								read_cnt = 0;		
                        end
                    end
					else if (((Instruct == RDAY7_C_0 || Instruct == RDAY7_4_0) && ITCRCE)  ||
							 ((Instruct == RDAY5_C_0 || Instruct == RDAY5_4_0) && ITCRCE) ||
							 ((Instruct == RDAY4_C_0 || Instruct == RDAY4_4_0) && !QPI_IT && ITCRCE)
							)
					begin
						crc_sgm_cnt = ((crc_sgm_cnt+1)%((sgm_size*2)+2));

						if (crc_sgm_cnt <= sgm_size*2 && crc_sgm_cnt % 2 == 1)
						begin
							ReturnSectorID(sect,Address);
							SecAddr = sect;
							READMEM(Address,SecAddr);

							CALC_CRC8(OutputD);

							Address = Address + 1;
						end

						if (crc_sgm_cnt <= sgm_size*2 && crc_sgm_cnt != 0)
						begin
							if (crc_sgm_cnt % 2 == 1) {DataDriveOut_Dout[1:0],DataDriveOut_SO,DataDriveOut_SI} = OutputD[7:4];
							else					  {DataDriveOut_Dout[1:0],DataDriveOut_SO,DataDriveOut_SI} = OutputD[3:0];
						end
						else
						begin
							if 	 (crc_sgm_cnt == (sgm_size*2 +1)) {DataDriveOut_Dout[1:0],DataDriveOut_SO,DataDriveOut_SI} = ~crc8_result[7:4];
							else							      {DataDriveOut_Dout[1:0],DataDriveOut_SO,DataDriveOut_SI} = ~crc8_result[3:0];
						end

						if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;

						if (crc_sgm_cnt == 0) crc8_result = 8'hFF;
					end
					else if ((Instruct == RDAY7_C_0 || Instruct == RDAY7_4_0) && !ITCRCE)
					begin
						if (!read_cnt[0])
						begin
							ReturnSectorID(sect,(Address-1));
							SecAddr = sect;
							READMEM(Address,SecAddr);
						end
						else
						begin
							Address = Address + 1;
						end

						if (!read_cnt[0]) {DataDriveOut_Dout[1:0],DataDriveOut_SO,DataDriveOut_SI} = OutputD[7:4];
						else			  {DataDriveOut_Dout[1:0],DataDriveOut_SO,DataDriveOut_SI} = OutputD[3:0];

						if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;

						read_cnt[0] = ~read_cnt[0];		
					end
					else if (((Instruct == RDAY5_C_0 || Instruct == RDAY5_4_0) && !ITCRCE) ||
							((Instruct == RDAY4_C_0 || Instruct == RDAY4_4_0) && !QPI_IT && !ITCRCE))
					begin
						if (!read_cnt[0])
						begin
							ReturnSectorID(sect,(Address-1));
							SecAddr = sect;
							READMEM(Address,SecAddr);
						end
						else
						begin
							Address = Address + 1;
						end

						if (!read_cnt[0]) {DataDriveOut_Dout[1:0],DataDriveOut_SO,DataDriveOut_SI} = OutputD[7:4];
						else			  {DataDriveOut_Dout[1:0],DataDriveOut_SO,DataDriveOut_SI} = OutputD[3:0];

						if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;

						read_cnt[0] = ~read_cnt[0];
					end
					else if ((Instruct == RDAY1_C_0 || Instruct == RDAY1_4_0
							 || Instruct == RDAY2_C_0 || Instruct == RDAY2_4_0)
							 && !QPI_IT && ITCRCE)
					begin
						if (read_cnt == 0)
						begin
							crc_sgm_cnt = (crc_sgm_cnt+1)%(sgm_size+1);

							if (crc_sgm_cnt <= sgm_size && crc_sgm_cnt != 0)
							begin
								ReturnSectorID(sect,Address);
								SecAddr = sect;
								READMEM(Address,SecAddr);

								CALC_CRC8(OutputD);

								Address = Address + 1;
							end
							else
							begin
								OutputD = ~crc8_result;
							end

							if (crc_sgm_cnt == 0) crc8_result = 8'hFF;
						end

						DataDriveOut_SO = OutputD[7-read_cnt];

						read_cnt = (read_cnt+1)%8;
					end
					else if ((Instruct == RDAY1_C_0 || Instruct == RDAY1_4_0
							 || Instruct == RDAY2_C_0 || Instruct == RDAY2_4_0)
							 && !QPI_IT && !ITCRCE)
					begin
						if (read_cnt == 0)
						begin
							ReturnSectorID(sect,Address);
							SecAddr = sect;
							READMEM(Address,SecAddr);

							Address = Address + 1;
						end

						DataDriveOut_SO = OutputD[7-read_cnt];

						read_cnt = (read_cnt+1)%8;
					end
                    else if (Instruct == RDSSR_C_0)
                    begin
                        if(Addr>=OTPLoAddr && Addr<=OTPHiAddr)
                        begin
                        //Read OTP Memory array
                            rd_fast = 1'b1;
                            rd_slow = 1'b0;
                            dual    = 1'b0;
                            ddr     = 1'b0;

							if (ITCRCE)
							begin
								if (QPI_IT)	
								begin
									if (otp_mem_cnt >= sgm_size*2) data_out = ~crc8_result[7:0];
									else 						   data_out = OTPMem[Addr];
								end
								else
								begin
									if (otp_mem_cnt == sgm_size) data_out = ~crc8_result[7:0];
									else						 data_out = OTPMem[Addr];
								end

								if (otp_mem_cnt == 0)
								begin
									crc8_result = 8'hFF;
								end

								if (QPI_IT)
								begin
									if ((otp_mem_cnt <= 2*sgm_size) && (otp_mem_cnt%2 == 1))
									begin
										CALC_CRC8(data_out);
									end
								end
								else
								begin
									if (read_cnt == 7) CALC_CRC8(OTPMem[Addr][7:0]);
								end
							end
							else
							begin
								data_out[7:0] = OTPMem[Addr];
							end

                            if (QPI_IT)
                            begin
								if (otp_mem_cnt % 2 == 0)
								begin
									DataDriveOut_Dout[1:0] = data_out[7:6];
                                	DataDriveOut_SO = data_out[5];
                                	DataDriveOut_SI = data_out[4];
								end
								else
								begin
									DataDriveOut_Dout[1:0] = data_out[3:2];
                                	DataDriveOut_SO = data_out[1];
                                	DataDriveOut_SI = data_out[0];
								end

								if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;

								if (!ITCRCE)
								begin
									if (otp_mem_cnt %2 == 1) Addr = Addr + 1;
								end
								else
								begin
									if (otp_mem_cnt <= 2*sgm_size && (otp_mem_cnt % 2 == 1)) Addr = Addr + 1;
								end

								if (otp_mem_cnt == (2*(sgm_size) + 1)) otp_mem_cnt = 0;
								else						           otp_mem_cnt = otp_mem_cnt + 1;
                            end
                            else
                            begin
								read_cnt = read_cnt + 1;
                                DataDriveOut_SO  = data_out[7-(read_cnt-1)];
								//DataDriveOut_SO = data_out[read_cnt - 1];

								if (read_cnt == 8)
                                begin
									read_cnt = 0;

                                    if (otp_mem_cnt != sgm_size)
									begin
										Addr = Addr + 1;
										otp_mem_cnt = otp_mem_cnt + 1;
									end
									else
										otp_mem_cnt = 0;
                                end
                            end
                        end
                        else if (Addr > OTPHiAddr)
                        begin
                        //OTP Read operation will not wrap to the
                        //starting address after the OTP address is at
                        //its maximum; instead, the data beyond the
                        //maximum OTP address will be undefined.
                            if (QPI_IT)
                            begin
                                DataDriveOut_Dout[1:0] = 2'bXX;
                                DataDriveOut_SO   	   = 1'bX;
                                DataDriveOut_SI   	   = 1'bX;

								if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;
                            end
                            else
                                DataDriveOut_SO = 1'bX;
                        end
                    end
                    else if (((Instruct == RDIDN_0_0 && QPI_IT) || Instruct == RDQID_0_0) && ITCRCE)
                    begin	
						crc_sgm_cnt = (crc_sgm_cnt+1)%((sgm_size*2)+2);

						if (crc_sgm_cnt <= 2*sgm_size && crc_sgm_cnt != 0 && crc_sgm_cnt % 2 == 1) 	    OutputD[7:4] = MDID_reg[4*((crc_sgm_cnt%32)+1) - 1 -: 4];
						else if (crc_sgm_cnt <= 2*sgm_size && crc_sgm_cnt != 0 && crc_sgm_cnt % 2 == 0) OutputD[3:0] = MDID_reg[4*((crc_sgm_cnt-1)%32) - 1 -: 4];
						else														    				OutputD	     = ~crc8_result;

						if (crc_sgm_cnt <= 2*sgm_size && crc_sgm_cnt != 0 && crc_sgm_cnt % 2 == 0)
						begin
							CALC_CRC8(OutputD);

							{DataDriveOut_Dout[1:0],DataDriveOut_SO,DataDriveOut_SI} = OutputD[3:0];
						end
						else if (crc_sgm_cnt == 0)
						begin
							{DataDriveOut_Dout[1:0],DataDriveOut_SO,DataDriveOut_SI} = OutputD[3:0];
						end
						else
						begin
							{DataDriveOut_Dout[1:0],DataDriveOut_SO,DataDriveOut_SI} = OutputD[7:4];
						end

						if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;

						if (crc_sgm_cnt == 0) crc8_result = 8'hFF;
					end
					else if (Instruct == RDIDN_0_0 && !QPI_IT && ITCRCE)
					begin
						if (read_cnt == 0)
						begin
							crc_sgm_cnt = (crc_sgm_cnt+1)%(sgm_size+1);

							if (crc_sgm_cnt == 0) 			OutputD[7:0] = ~crc8_result;
							else if (crc_sgm_cnt % 16 == 0) OutputD[7:0] = MDID_reg[127:120];
							else							OutputD[7:0] = MDID_reg[8*(crc_sgm_cnt%16) - 1 -: 8];

							if (crc_sgm_cnt <= sgm_size) CALC_CRC8(OutputD);

							if (crc_sgm_cnt == 0) crc8_result = 8'hFF;
						end

						DataDriveOut_SO = OutputD[7-read_cnt];

						read_cnt = (read_cnt+1)%8;
					end
					else if (((Instruct == RDIDN_0_0 && QPI_IT) || Instruct == RDQID_0_0) && !ITCRCE)
					begin
						if (read_cnt %2 == 0) OutputD[7:4] = MDID_reg[((read_cnt/2)+1)*8 - 1 -: 4];
						else				  OutputD[3:0] = MDID_reg[(read_cnt*4) - 1 -: 4];

						if (read_cnt %2 == 0) {DataDriveOut_Dout[1:0],DataDriveOut_SO,DataDriveOut_SI} = OutputD[7:4];
						else				  {DataDriveOut_Dout[1:0],DataDriveOut_SO,DataDriveOut_SI} = OutputD[3:0];

						if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;

						read_cnt = (read_cnt+1)%32;
					end
					else if (Instruct == RDIDN_0_0 && !QPI_IT && !ITCRCE)
					begin
						if (read_cnt%8 == 0)
						begin
							OutputD[7:0] = MDID_reg[8*((read_cnt/8)+1)-1 -: 8];
						end

						DataDriveOut_SO = OutputD[7-(read_cnt%8)];

						read_cnt = (read_cnt+1)%128;
                    end
					else if (Instruct == RDUID_0_0 && !QPI_IT && ITCRCE)
					begin
						if (read_cnt == 0)
						begin
							crc_sgm_cnt = (crc_sgm_cnt+1)%((sgm_size)+1);

							if (crc_sgm_cnt == 0) OutputD[7:0] = ~crc8_result;
							else if (crc_sgm_cnt % 8 == 0) OutputD[7:0] = UID_reg[63:56];
							else						   OutputD[7:0] = UID_reg[8*(crc_sgm_cnt%8) - 1 -: 8];
							//else 				  OutputD[7:0] = UID_reg[8*(crc_sgm_cnt%9 + crc_sgm_cnt/9) -1 -: 8];

							if (crc_sgm_cnt <= sgm_size) CALC_CRC8(OutputD);

							if (crc_sgm_cnt == 0) crc8_result = 8'hFF;
						end

						DataDriveOut_SO = OutputD[7-read_cnt];

						if (read_cnt<7) read_cnt = read_cnt + 1;
						else			read_cnt = 0;
					end
                    else if (Instruct == RDUID_0_0 && QPI_IT && ITCRCE)
                    begin
						crc_sgm_cnt = (crc_sgm_cnt+1)%((sgm_size*2)+2);

						if (crc_sgm_cnt <= 2*sgm_size && crc_sgm_cnt != 0 && crc_sgm_cnt % 2 == 1) 	    OutputD[7:4] = UID_reg[4*((crc_sgm_cnt%16)+1) - 1 -: 4];
						else if (crc_sgm_cnt <= 2*sgm_size && crc_sgm_cnt != 0 && crc_sgm_cnt % 2 == 0) OutputD[3:0] = UID_reg[4*((crc_sgm_cnt-1)%16) - 1 -: 4];
						else														    				OutputD	     = ~crc8_result;

						if (crc_sgm_cnt <= 2*sgm_size && crc_sgm_cnt != 0 && crc_sgm_cnt % 2 == 0)
						begin
							CALC_CRC8(OutputD);

							{DataDriveOut_Dout[1:0],DataDriveOut_SO,DataDriveOut_SI} = OutputD[3:0];
						end
						else if (crc_sgm_cnt == 0)
						begin
							{DataDriveOut_Dout[1:0],DataDriveOut_SO,DataDriveOut_SI} = OutputD[3:0];
						end
						else
						begin
							{DataDriveOut_Dout[1:0],DataDriveOut_SO,DataDriveOut_SI} = OutputD[7:4];
						end

						if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;

						if (crc_sgm_cnt == 0) crc8_result = 8'hFF;
                    end
					else if (Instruct == RDUID_0_0 && QPI_IT && !ITCRCE)
					begin
						if (read_cnt %2 == 0) OutputD[7:4] = UID_reg[((read_cnt/2)+1)*8 - 1 -: 4];
						else				  OutputD[3:0] = UID_reg[(read_cnt*4) - 1 -: 4];

						if (read_cnt %2 == 0) {DataDriveOut_Dout[1:0],DataDriveOut_SO,DataDriveOut_SI} = OutputD[7:4];
						else				  {DataDriveOut_Dout[1:0],DataDriveOut_SO,DataDriveOut_SI} = OutputD[3:0];

						if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;

						if (read_cnt<15) read_cnt = read_cnt + 1;
						else			 read_cnt = 0;
					end
					else if (Instruct == RDUID_0_0 && !QPI_IT && !ITCRCE)
					begin
						if (read_cnt%8 == 0)
						begin
							OutputD[7:0] = UID_reg[8*((read_cnt/8)+1)-1 -: 8];
						end

						DataDriveOut_SO = OutputD[7-(read_cnt%8)];

						if (read_cnt<63) read_cnt = read_cnt + 1;
						else		     read_cnt = 0;
					end
                    else if ((Instruct == RSFDP_C_0) && (!QPI_IT) && ITCRCE)
                    begin
						if (Address <= SFDPHiAddr)
						begin
							if (read_cnt == 0)
							begin
								crc_sgm_cnt = (crc_sgm_cnt+1)%(sgm_size+1);

								if (crc_sgm_cnt == 0) OutputD[7:0] = ~crc8_result;
								else				  OutputD[7:0] = SFDP_array[Address[15:0]];

								if (Address < SFDPHiAddr) Address = Address + 'd1;
								else					  Address = 0;

								if (crc_sgm_cnt <= sgm_size) CALC_CRC8(OutputD);

								if (crc_sgm_cnt == 0) crc8_result = 8'hFF;
							end

							DataDriveOut_SO = OutputD[7-read_cnt];

							if (read_cnt<7) read_cnt = read_cnt + 1;
							else		    read_cnt = 0;
						end
						else
						begin
							DataDriveOut_SO = 1'bX;
						end
					end					
                    else if ((Instruct == RSFDP_C_0) && QPI_IT && ITCRCE)  //falling edge write, IDLE
                    begin
                        //Read Memory array
                        rd_fast = 1'b0;
                        rd_slow = 1'b0;
                        dual    = 1'b1;
                        ddr     = 1'b1;
						if (Address <= SFDPHiAddr)
                        begin
							crc_sgm_cnt = (crc_sgm_cnt+1)%((sgm_size*2)+2);

							if (crc_sgm_cnt <= 2*sgm_size && crc_sgm_cnt != 0) OutputD = SFDP_array[Address[15:0]];
							else							 	 			   OutputD = ~crc8_result;

							if (crc_sgm_cnt <= 2*sgm_size && crc_sgm_cnt % 2 == 0)
							begin
								CALC_CRC8(SFDP_array[Address[15:0]]);
								
								if (Address < SFDPHiAddr) Address = Address + 'd1;
								else					  Address = 0;

								{DataDriveOut_Dout[1:0],DataDriveOut_SO,DataDriveOut_SI} = OutputD[3:0];
							end
							else if (crc_sgm_cnt == 0)
							begin
								{DataDriveOut_Dout[1:0],DataDriveOut_SO,DataDriveOut_SI} = OutputD[3:0];
							end
							else
							begin
								{DataDriveOut_Dout[1:0],DataDriveOut_SO,DataDriveOut_SI} = OutputD[7:4];
							end

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;

							if (crc_sgm_cnt == 0) crc8_result = 8'hFF;
						end
						else
						begin
						  {DataDriveOut_Dout[1:0],DataDriveOut_SO,DataDriveOut_SI} = 8'hx;

						  if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;
						end
					end
					else if ((Instruct == RSFDP_C_0) && (!QPI_IT) && !ITCRCE)
					begin
						if (Address <= SFDPHiAddr)
                        begin
							if (read_cnt % 8 == 0)
							begin
								OutputD = SFDP_array[Address[15:0]];
							end

							DataDriveOut_SO = OutputD[7-read_cnt];

							if (read_cnt < 7) read_cnt = read_cnt + 1;
							else			  read_cnt = 0;

							if (read_cnt == 0)
							begin
								if (Address < SFDPHiAddr) Address = Address + 'd1;
								else					  Address = 0;
							end
                        end
						else
							DataDriveOut_SO  =  1'bX;
					end
					else if ((Instruct == RSFDP_C_0) && QPI_IT && !ITCRCE)
					begin
						//Read Memory array
                        rd_fast = 1'b0;
                        rd_slow = 1'b0;
                        dual    = 1'b1;
                        ddr     = 1'b1;
						if (Address <= SFDPHiAddr)
                        begin
							OutputD = SFDP_array[Address[15:0]];

							if (!read_cnt) {DataDriveOut_Dout[1:0],DataDriveOut_SO,DataDriveOut_SI} = OutputD[7:4];
							else		   {DataDriveOut_Dout[1:0],DataDriveOut_SO,DataDriveOut_SI} = OutputD[3:0];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;

							if (read_cnt)
							begin
								if (Address < SFDPHiAddr) Address = Address + 'd1;
								else					  Address = 0;
							end

							read_cnt = ~read_cnt;
						end
						else
						begin
						  {DataDriveOut_Dout[1:0],DataDriveOut_SO,DataDriveOut_SI} = 8'hx;

						  if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;
						end
					end
                    else if (Instruct == RDECC_4_0 || Instruct == RDECC_C_0)
                    begin
                    	if (QPI_IT)
                        begin
							if (data_cnt==0)
							begin
								data_cnt = data_cnt + 1;

                            	DataDriveOut_Dout[1:0] = ECSV[7:6];
                            	DataDriveOut_SO   	   = ECSV[5];
                            	DataDriveOut_SI   	   = ECSV[4];
							end
							else if (data_cnt==1)
							begin
								data_cnt = data_cnt + 1;

								DataDriveOut_Dout[1:0] = ECSV[3:2];
								DataDriveOut_SO		   = ECSV[1];
								DataDriveOut_SI		   = ECSV[0];
							end
							else if (data_cnt==2)
							begin
								data_cnt = data_cnt + 1;

								DataDriveOut_Dout[1:0] = ~ECSV[7:6];
								DataDriveOut_SO 	   = ~ECSV[5];
								DataDriveOut_SI		   = ~ECSV[4];
							end
							else
							begin
								data_cnt = 0;

								DataDriveOut_Dout = ~ECSV[3:2];
                            	DataDriveOut_SO   = ~ECSV[1];
                            	DataDriveOut_SI   = ~ECSV[0];
							end

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;
                        end
                        else
                        begin
							if (data_cnt==0)
							begin
                            	DataDriveOut_SO = ECSV[7-read_cnt];
							end
							else
							begin
								DataDriveOut_SO = ~ECSV[7-read_cnt];
							end

                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8)
							begin
								if (data_cnt==0) data_cnt = 1;
								else			 data_cnt = 0;

                                read_cnt = 0;
							end
                        end
                    end
                    else if (Instruct == RDCRC_4_0)
                    begin
                        if (Addr_idcfi <= 3)
                        begin
                            data_out[7:0] = ICRV[8*Addr_idcfi+7 -: 8];
                            if (QPI_IT)
                            begin
                                for (i=0;i<=5;i=i+1)
                                begin
                                    DataDriveOut_Dout[5-i] = data_out[7-i-read_cnt];
                                end
                                DataDriveOut_SO = data_out[1-read_cnt];
                                DataDriveOut_SI = data_out[0-read_cnt];

								if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;

                                read_cnt = read_cnt + 1;
                                if (read_cnt == 1)
                                begin
                                    read_cnt = 0;
                                    Addr_idcfi = Addr_idcfi + 1;
                                end
                            end
                        end
                    end
					else if ((Instruct == RDDYB_4_0) || (Instruct == RDDYB_C_0))
                    begin
                        ReturnSectorID(sect,Address);

                        if (DYB_bits[sect] == 1)
                            DYAV[7:0] = 8'hFF;
                        else
                        begin
                            DYAV[7:0] = 8'h0;
                        end

						if (QPI_IT)
                        begin
                            data_out_nibble[0]  = DYAV[7:4];
							data_out_nibble[1]  = DYAV[3:0];
							data_out_nibble[2]  = ~DYAV[7:4];
							data_out_nibble[3]  = ~DYAV[3:0];
							{DataDriveOut_Dout[1:0], DataDriveOut_SO, DataDriveOut_SI} = data_out_nibble[read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;
                            
							read_cnt = read_cnt + 1;							
							if ((ITCRCE && read_cnt == 4) || ~ITCRCE && (read_cnt == 2))
								 read_cnt = 0;	
                        end
                        else
                        begin
						    data_out[7:0]   = DYAV;
							data_outb[7:0]  = ~DYAV;
							if(read_cnt < 8)
							    DataDriveOut_SO = data_out[7-read_cnt];
							else if(read_cnt >= 8)
							    DataDriveOut_SO = data_outb[15-read_cnt];
							read_cnt = read_cnt + 1;
							if ((ITCRCE && read_cnt == 16) || ~ITCRCE && (read_cnt == 8))
								read_cnt = 0;		
                        end
                    end						
					else if (Instruct == RDPPB_4_0 || Instruct == RDPPB_C_0)
                    begin
                        ReturnSectorID(sect,Address);

                        if (PPB_bits[sect] == 1)
                            PPAV[7:0] = 8'hFF;
                        else
                        begin
                            PPAV[7:0] = 8'h0;
                        end

						if (QPI_IT)
                        begin
                            data_out_nibble[0]  = PPAV[7:4];
							data_out_nibble[1]  = PPAV[3:0];
							data_out_nibble[2]  = ~PPAV[7:4];
							data_out_nibble[3]  = ~PPAV[3:0];
							{DataDriveOut_Dout[1:0], DataDriveOut_SO, DataDriveOut_SI} = data_out_nibble[read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;
                            
							read_cnt = read_cnt + 1;							
							if ((ITCRCE && read_cnt == 4) || ~ITCRCE && (read_cnt == 2))
								 read_cnt = 0;	
                        end
                        else
                        begin
						    data_out[7:0]   = PPAV;
							data_outb[7:0]  = ~PPAV;
							if(read_cnt < 8)
							    DataDriveOut_SO = data_out[7-read_cnt];
							else if(read_cnt >= 8)
							    DataDriveOut_SO = data_outb[15-read_cnt];
							read_cnt = read_cnt + 1;
							if ((ITCRCE && read_cnt == 16) || ~ITCRCE && (read_cnt == 8))
								read_cnt = 0;		
                        end
                    end															
                    else if (Instruct == RDPLB_0_0)					
					begin
                        if (QPI_IT)
                        begin
                            data_out_nibble[0]  = PPLV[7:4];
							data_out_nibble[1]  = PPLV[3:0];
							data_out_nibble[2]  = ~PPLV[7:4];
							data_out_nibble[3]  = ~PPLV[3:0];
							{DataDriveOut_Dout[1:0], DataDriveOut_SO, DataDriveOut_SI} = data_out_nibble[read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;
                            
							read_cnt = read_cnt + 1;							
							if ((ITCRCE && read_cnt == 4) || ~ITCRCE && (read_cnt == 2))
								 read_cnt = 0;	
                        end
                        else
                        begin
						    data_out[7:0]   = PPLV;
							data_outb[7:0]  = ~PPLV;
							if(read_cnt < 8)
							    DataDriveOut_SO = data_out[7-read_cnt];
							else if(read_cnt >= 8)
							    DataDriveOut_SO = data_outb[15-read_cnt];
								read_cnt = read_cnt + 1;
							if ((ITCRCE && read_cnt == 16) || ~ITCRCE && (read_cnt == 8))
								read_cnt = 0;		
                        end
                    end								
                end
            end
            
            AUTOBOOT:
            begin
                if (start_autoboot == 1)
                begin

                    if (oe)
                    begin
                        any_read = 1'b1;
                        if (QPI_IT)
                        begin           //max SCK frequency is 100MHz
                            rd_fast = 1'b0;
                            rd_slow = 1'b0;
                            dual    = 1'b1;
                            ddr     = 1'b1;
                            
                            ReturnSectorID(sect,read_addr);
                            SecAddr = sect;
                            READMEM(read_addr,SecAddr);
                            data_out[7:0] = OutputD;
                            for (i=0;i<=5;i=i+1)
                            begin
                                DataDriveOut_Dout[5-i] = data_out[7-i-read_cnt];
                            end
							DataDriveOut_SO = data_out[1];
							DataDriveOut_SI = data_out[0];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;

                            read_cnt = read_cnt + 1;
                            if (read_cnt == 1)
                            begin
                                read_cnt = 0;
                                read_addr = read_addr + 1;
                            end
                        end
                        else
                        begin 
                            rd_fast = 1'b0;
                            rd_slow = 1'b1;
                            dual    = 1'b0;
                            ddr     = 1'b0;
                            ReturnSectorID(sect,read_addr);
                            SecAddr = sect;
                            READMEM(read_addr,SecAddr);
                            data_out[7:0] = OutputD;
                            DataDriveOut_SO = data_out[7-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8)
                            begin
                                read_cnt = 0;
                                read_addr = read_addr + 1;
                            end
                        end
                    end
                end
            end

			WRITE_ALL_REG:
			begin
				if (QPI_IT)
                begin
                    rd_fast = 1'b1;
                    rd_slow = 1'b0;
                    dual    = 1'b1;
                    ddr     = 1'b0;
                end
                else
                begin
                    rd_fast = 1'b1;
                    rd_slow = 1'b0;
                    dual    = 1'b0;
                    ddr     = 1'b0;
                end

				if (WDONE && CSDONE)
				begin
					STR1V[0] = 1'b0; // RDYBSY
                    STR1V[1] = 1'b0; // WRPGEN

					if (!PLPROT_O)
					begin
						if (!TLPROT)
						begin
							if (TLPROT == 0)
                            //The Freeze Bit, when set to 1, locks the current
                            //state of the LBPROT2-0 bits in Status Register.
                            begin
								STR1V[4] = QPI_IT ? quad_data_in[0][0] : Data_in[4];//LBPROT2
                                STR1V[3] = QPI_IT ? quad_data_in[1][3] : Data_in[3];//LBPROT1
                                STR1V[2] = QPI_IT ? quad_data_in[1][2] : Data_in[2];//LBPROT0

                                BP_bits = {STR1V[4],STR1V[3],STR1V[2]};

                                change_BP    = 1'b1;
                                #1 change_BP = 1'b0;
                            end
						end
					end

					if (wrreg_bytes>1)
					begin
						CFR1V[0] = QPI_IT ? quad_data_in[3][0] : Data_in[8];
					end

					if (wrreg_bytes>2)
					begin
						CFR2V[7]   = QPI_IT ? quad_data_in[4][3] : Data_in[2*8+7];
						CFR2V[3:0] = QPI_IT ? quad_data_in[5][3:0] : Data_in[2*8+3:2*8];
					end

					if (wrreg_bytes>3)
					begin
						CFR3V[5] = QPI_IT ? quad_data_in[6][1] : Data_in[3*8+5];
					end

					if (wrreg_bytes>4)
					begin
						CFR4V[7:5] = QPI_IT ? quad_data_in[8][3:1] : Data_in[4*8+7:4*8+5];
						CFR4V[4] = QPI_IT ? quad_data_in[8][0] : Data_in[4*8+4];
						CFR4V[3] = QPI_IT ? quad_data_in[9][3] : Data_in[4*8+3];
						CFR4V[1:0] = QPI_IT ? quad_data_in[9][1:0] : Data_in[4*8+1:4*8];
					end

					if (wrreg_bytes>5)
					begin
						CFR5V[7] = QPI_IT ? quad_data_in[10][3] : Data_in[5*8+7];
						CFR5V[1] = QPI_IT ? quad_data_in[11][1] : Data_in[5*8+1];
						CFR5V[0] = QPI_IT ? quad_data_in[11][0] : Data_in[5*8];
					end
				end
			end

            WRITE_ANY_REG:
            begin
                if (QPI_IT)
                begin
                    rd_fast = 1'b1;
                    rd_slow = 1'b0;
                    dual    = 1'b1;
                    ddr     = 1'b0;
                end
                else
                begin
                    rd_fast = 1'b1;
                    rd_slow = 1'b0;
                    dual    = 1'b0;
                    ddr     = 1'b0;
                end

                if (oe)
                begin
                    any_read = 1'b1;
                    if (Instruct == RDSR1_0_0)
                    begin
                    //Read Status Register 1
                       if (QPI_IT)
                        begin
							if(read_cnt == 0)
							  data_out[7:0] = STR1V;
							else 
							  data_out[7:0] = ~STR1V;
							for (i=0;i<=5;i=i+1)
							begin
								DataDriveOut_Dout[5-i] = data_out[7-i-read_cnt];
							end
							DataDriveOut_SO = data_out[1-read_cnt];
							DataDriveOut_SI = data_out[0-read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;
							
							read_cnt = read_cnt + 1;
							if (read_cnt == (1 + ITCRCE))
							begin
								read_cnt = 0;
							end							
                        end
                        else
                        begin
							DataDriveOut_SO = STR1Vbbar[15-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8 + 8*ITCRCE)
                                read_cnt = 0;
                        end
                    end
                    else if (Instruct == RDSR2_0_0)
                    begin
                        //Read Status Register 2
                        if (QPI_IT)
                        begin
                            data_out[7:0] = STR2V;
                            for (i=0;i<=5;i=i+1)
                            begin
                                DataDriveOut_Dout[5-i] = data_out[7-i-read_cnt];
                            end
                            DataDriveOut_SO = data_out[1-read_cnt];
                            DataDriveOut_SI = data_out[0-read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;

                            read_cnt = read_cnt + 1;
                            if (read_cnt == 1)
                            begin
                                read_cnt = 0;
                            end
                        end
                        else
                        begin
                            DataDriveOut_SO = STR2V[7-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8)
                                read_cnt = 0;
                        end
                    end
                    else if (Instruct == RDARG_C_0)
                    begin
                          READ_ALL_REG(read_addr, RDAR_reg);

                        if (QPI_IT)
                        begin
                            data_out_nibble[0]  = RDAR_reg[7:4];
							data_out_nibble[1]  = RDAR_reg[3:0];
							data_out_nibble[2]  = ~RDAR_reg[7:4];
							data_out_nibble[3]  = ~RDAR_reg[3:0];
							{DataDriveOut_Dout[1:0], DataDriveOut_SO, DataDriveOut_SI} = data_out_nibble[read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;

                            read_cnt = read_cnt + 1;							
							if ((ITCRCE && read_cnt == 4) || ~ITCRCE && (read_cnt == 2))
								 read_cnt = 0;	
                        end
                        else
                        begin
						    data_out[7:0]   = RDAR_reg;
							data_outb[7:0]  = ~RDAR_reg;
							if(read_cnt < 8)
							    DataDriveOut_SO = data_out[7-read_cnt];
							else if(read_cnt >= 8)
							    DataDriveOut_SO = data_outb[15-read_cnt];
							read_cnt = read_cnt + 1;
							if ((ITCRCE && read_cnt == 16) || ~ITCRCE && (read_cnt == 8))
								read_cnt = 0;		
                        end
                    end
                end

                new_pass_byte = WRAR_reg_in;
                if (Addr == 32'h00000020)
                    old_pass_byte = PWDO[7:0];
                else if (Addr == 32'h00000021)
                    old_pass_byte = PWDO[15:8];
                else if (Addr == 32'h00000022)
                    old_pass_byte = PWDO[23:16];
                else if (Addr == 32'h00000023)
                    old_pass_byte = PWDO[31:24];
                else if (Addr == 32'h00000024)
                    old_pass_byte = PWDO[39:32];
                else if (Addr == 32'h00000025)
                    old_pass_byte = PWDO[47:40];
                else if (Addr == 32'h00000026)
                    old_pass_byte = PWDO[55:48];
                else if (Addr == 32'h00000027)
                    old_pass_byte = PWDO[63:56];

                for (i=0;i<=7;i=i+1)
                begin
                    if (old_pass_byte[j] == 0)
                        new_pass_byte[j] = 0;
                end

                if(WDONE && CSDONE && ~WRAR_reg_in_correct && ITCRCE)
				   STR1V[0] = 1'b0; // RDYBSY
				else if (WDONE && CSDONE && ((WRAR_reg_in_correct && ITCRCE) || ~ITCRCE))
                begin
                    STR1V[0] = 1'b0; // RDYBSY
                    STR1V[1] = 1'b0; // WRPGEN

                    if (Addr == 32'h00000000) // SR1_NV;
                    begin
                        if (~PLPROT_O)
                        begin
                            if (TLPROT == 0)
                            //The Freeze Bit, when set to 1, locks the current
                            //state of the LBPROT2-0 bits in Status Register.
                            begin
                                    STR1N[4] = WRAR_reg_in[4];//LBPROT2_NV
                                    STR1N[3] = WRAR_reg_in[3];//LBPROT1_NV
                                    STR1N[2] = WRAR_reg_in[2];//LBPROT0_NV

                                    STR1V[4] = WRAR_reg_in[4];//LBPROT2
                                    STR1V[3] = WRAR_reg_in[3];//LBPROT1
                                    STR1V[2] = WRAR_reg_in[2];//LBPROT0

                                    BP_bits = {STR1V[4],STR1V[3],STR1V[2]};

                                    change_BP    = 1'b1;
                                    #1 change_BP = 1'b0;
                            end
                        end
                    end
                    else if (Addr == 32'h00000002) // CFR1_NV;
                    begin
                        if (PLPROT_O == 1'b0 && ASPPER)
                        begin
                            CFR1N[4] = WRAR_reg_in[4];//PLPROT_O
                            CFR1V[4] = WRAR_reg_in[4];//PLPROT
                            if (~TLPROT)
                            begin
                                //CFR1N[6] = WRAR_reg_in[6];// SP4KBS_NV
                                //CFR1V[6] = WRAR_reg_in[6];//SP4KBS  
                                CFR1N[5] = WRAR_reg_in[5];//TBPROT_NV
                                CFR1V[5] = WRAR_reg_in[5];//TBPROT 
                                
                                //CFR1N[2] = WRAR_reg_in[2];//TB4KBS_NV
                                //CFR1V[2] = WRAR_reg_in[2];//TB4KBS
                                change_TBPARM = 1'b1;
                                #1 change_TBPARM = 1'b0;
                            end
                        end
                    end
                    else if (Addr == 32'h00000003) // CFR2_NV
                    begin
                            CFR2N[3:0] = WRAR_reg_in[3:0];// RL_NV[3:0]
                            CFR2V[3:0] = WRAR_reg_in[3:0];// RL[3:0]
                            CFR2N[7]   = WRAR_reg_in[7];  // ADRBYT_NV
                            CFR2V[7]   = WRAR_reg_in[7];  // ADRBYT_V
                    end
                    else if (Addr == 32'h00000004) // CFR3_NV
                    begin
                        CFR3N[5] = WRAR_reg_in[5];// BLKCHK_NV
                        CFR3V[5] = WRAR_reg_in[5];// BLKCHK_V
                    end
                    else if (Addr == 32'h00000005) // CFR4N
                    begin
//                         if (CFR4N[7:5] == 3'b000)
//                         begin
                            CFR4N[7:5] = WRAR_reg_in[7:5];// IOIMPD_NV[2:0]
                            CFR4V[7:5] = WRAR_reg_in[7:5];// IOIMPD[2:0]
//                         end

//                         if (CFR4N[4] == 1'b0)
//                         begin
                            CFR4N[4] = WRAR_reg_in[4];// RBSTWP_NV
                            CFR4V[4] = WRAR_reg_in[4];// RBSTWP
//                         end
                        
//                         if (CFR4N[3] == 1'b0)
//                         begin
                            CFR4N[3] = WRAR_reg_in[3];// ECC12S
                            CFR4V[3] = WRAR_reg_in[3];// ECC12S
//                         end
                        
                        CFR4N[2] = WRAR_reg_in[2];// DPDPOR_NV
                        CFR4V[2]  = WRAR_reg_in[2];// DPDPOR 

//                         if (CFR4N[1:0] == 2'b00)
//                         begin
                            CFR4N[1:0] = WRAR_reg_in[1:0];// RBSTWL_NV[1:0]
                            CFR4V[1:0] = WRAR_reg_in[1:0];// RBSTWL[1:0]
//                         end
                    end
                    else if (Addr == 32'h00000006) // CFR5N
                    begin
					   CFR5N[7] = WRAR_reg_in[7];// DSOSDR_NV // new spec
					   CFR5V[7] = WRAR_reg_in[7];// DSOSDR
					   CFR5N[1] = WRAR_reg_in[1];// DDR_NV
					   CFR5V[1] = WRAR_reg_in[1];// SDRDDR
                       CFR5N[0] = WRAR_reg_in[0];// OPI_NV
                       CFR5V[0] = WRAR_reg_in[0];// QPI_IT
                    end

					else if (Addr == 32'h00000008) // ICEN
                    begin
						ICEN[2:1] = WRAR_reg_in[2:1];
						ICEN[0]   = WRAR_reg_in[0]; // ITCRCE						
                    end
					
					else if (Addr == 32'h00800008) // ICEV
                    begin
						ICEV[2:1] = WRAR_reg_in[2:1];	
						ICEV[0]   = WRAR_reg_in[0]; // ITCRCE
                    end
					
                    else if (Addr == 32'h00000020)
                    // Password_reg[7:0];
                    begin
                        PWDO[7:0] = new_pass_byte;
                    end
                    else if (Addr == 32'h00000021)
                    // Password_reg[15:8];
                    begin
                        PWDO[15:8] = new_pass_byte;
                    end
                    else if (Addr == 32'h00000022)
                    // Password_reg[23:16];
                    begin
                        PWDO[23:16] = new_pass_byte;
                    end
                    else if (Addr == 32'h00000023)
                    // Password_reg[31:24];
                    begin
                        PWDO[31:24] = new_pass_byte;
                    end
                    else if (Addr == 32'h00000024)
                    // Password_reg[39:32];
                    begin
                        PWDO[39:32] = new_pass_byte;
                    end
                    else if (Addr == 32'h00000025)
                    // Password_reg[47:40];
                    begin
                        PWDO[47:40] = new_pass_byte;
                    end
                    else if (Addr == 32'h00000026)
                    // Password_reg[55:48];
                    begin
                        PWDO[55:48] = new_pass_byte;
                    end
                    else if (Addr == 32'h00000027)
                    // Password_reg[63:56];
                    begin
                        PWDO[63:56] = new_pass_byte;
                    end
                    else if (Addr == 32'h00000030) // ASP_reg[7:0]
                    begin
                        if (ASPDYB == 1'b0 && WRAR_reg_in[4] == 1'b1)
							$display("ASPDYB bit is allready programmed");
                        else
							ASPO[4] = WRAR_reg_in[4];//ASPDYB
						if (ASPPPB == 1'b0 && WRAR_reg_in[3] == 1'b1)
							$display("ASPPPB bit is allready programmed");
						else
							ASPO[3] = WRAR_reg_in[3];//ASPPPB

						if (ASPPRM == 1'b0 && WRAR_reg_in[0] == 1'b1)
							$display("ASPPRM bit is allready programmed");
						else
							ASPO[0] = WRAR_reg_in[0];//ASPPRM
							
						if (ASPPER == 1'b0 && WRAR_reg_in[1] == 1'b1)
							$display("ASPPER bit is allready programmed");
						else
							ASPO[1] = WRAR_reg_in[1];//ASPPER
						
						if (ASPPWD == 1'b0 && WRAR_reg_in[2] == 1'b1)
							$display("ASPPWD bit is allready programmed");
						else
                           ASPO[2] = WRAR_reg_in[2];//ASPPWD
                    end
                    else if (Addr == 32'h00000031)
                    // ASP_reg[15:8];
                    begin
                        $display("RFU bits");
                    end
                    else if (Addr == 32'h00000042) // 
                    begin
                        ATBN[7:0] = WRAR_reg_in[7:0];// 
                    end
                    else if (Addr == 32'h00000043) // 
                    begin
                        ATBN[15:8] = WRAR_reg_in[7:0];// 
                    end
                    else if (Addr == 32'h00000044) // 
                    begin
                        ATBN[23:16] = WRAR_reg_in[7:0];// 
                    end
                    else if (Addr == 32'h00000045) // 
                    begin
                        ATBN[31:24] = WRAR_reg_in[7:0];// 
                    end
                    else if (Addr == 32'h00800000) // SR1_V
                    begin
                        if (~PLPROT_O)
                        begin
                            if (TLPROT == 0)
                            //The Freeze Bit, when set to 1, locks the current
                            //state of the LBPROT2-0 bits in Status Register.
                            begin
                                    STR1V[4] = WRAR_reg_in[4];//LBPROT2
                                    STR1V[3] = WRAR_reg_in[3];//LBPROT1
                                    STR1V[2] = WRAR_reg_in[2];//LBPROT0

                                    BP_bits = {STR1V[4],STR1V[3],STR1V[2]};

                                    change_BP    = 1'b1;
                                    #1 change_BP = 1'b0;
                            end
                        end
                    end
                    else if (Addr == 32'h00800001) // SR2_V
                    begin
                        $display("Status Register 2 does not have user ");
                        $display("programmable bits, all defined bits are  ");
                        $display("volatile read only status.");
                    end
                    else if (Addr == 32'h00800002) // CFR1_V
                    begin
                        
                        CFR1V[0] = WRAR_reg_in[0];// TLPROT
     
                    end
                    else if (Addr == 32'h00800003) // CR2_V
                    begin
                        CFR2V[3:0] = WRAR_reg_in[3:0];// MEMLAT[3:0]
                        CFR2V[7]   = WRAR_reg_in[7];  // ADRBYT_V
                    end
                    else if (Addr == 32'h00800004) // CR3_V
                    begin
                        CFR3V[5] = WRAR_reg_in[5];// BLKCHK

                    end
                    else if (Addr == 32'h00800005) // CFR4V
                    begin
                        CFR4V[7:5] = WRAR_reg_in[7:5];// OI[2:0]
                        CFR4V[4]   = WRAR_reg_in[4];  // WE
                        CFR4V[3]  = WRAR_reg_in[3];//
                        CFR4V[1:0] = WRAR_reg_in[1:0];// WL[1:0]
                    end
                    else if (Addr == 32'h00800006) // CR5_V
                    begin
                        CFR5V[7] = WRAR_reg_in[7];// DSOSDR //new spec
                        CFR5V[1] = WRAR_reg_in[1];// SDRDDR
                        CFR5V[0] = WRAR_reg_in[0];// QPI_IT
                    end
                    else if (Addr == 32'h00800008) // ICEV
                    begin
						ICEV[2:1] = WRAR_reg_in[2:1]; // ITCRCE
						ICEV[0]   = WRAR_reg_in[0]; // ITCRCE
                    end
                    else if (Addr == 32'h00800068 && QPI_IT) // INC0V
                    begin
                        INC0V[7] = WRAR_reg_in[7];
                        INC0V[4] = WRAR_reg_in[4];
                        INC0V[1] = WRAR_reg_in[1]; 
                        INC0V[0] = WRAR_reg_in[0]; 
                    end
                    else if (Addr == 32'h00800067) // INS0V
                    begin
                        INS0V[4] = WRAR_reg_in[4];
                        INS0V[1] = WRAR_reg_in[1]; 
                        INS0V[0] = WRAR_reg_in[0]; 
                    end
                end
            end

            PAGE_PG :
            begin
                if (QPI_IT)
                begin
                    rd_fast = 1'b1;
                    rd_slow = 1'b0;
                    dual    = 1'b1;
                    ddr     = 1'b0;
                end
                else
                begin
                    rd_fast = 1'b1;
                    rd_slow = 1'b0;
                    dual    = 1'b0;
                    ddr     = 1'b0;
                end

                if (oe)
                begin
                    any_read = 1'b1;
                    if (Instruct == RDSR1_0_0)
                    begin
                    //Read Status Register 1
                       if (QPI_IT)
                        begin
							if(read_cnt == 0)
							  data_out[7:0] = STR1V;
							else 
							  data_out[7:0] = ~STR1V;
							for (i=0;i<=5;i=i+1)
							begin
								DataDriveOut_Dout[5-i] = data_out[7-i-read_cnt];
							end
							DataDriveOut_SO = data_out[1-read_cnt];
							DataDriveOut_SI = data_out[0-read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;
							
							read_cnt = read_cnt + 1;
							if (read_cnt == (1 + ITCRCE))
							begin
								read_cnt = 0;
							end							
                        end
                        else
                        begin
							DataDriveOut_SO = STR1Vbbar[15-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8 + 8*ITCRCE)
                                read_cnt = 0;
                        end
                    end
                    else if (Instruct == RDSR2_0_0)
                    begin
                        //Read Status Register 2
                        if (QPI_IT)
                        begin
                            data_out[7:0] = STR2V;
                            for (i=0;i<=5;i=i+1)
                            begin
                                DataDriveOut_Dout[5-i] = data_out[7-i-read_cnt];
                            end
                            DataDriveOut_SO = data_out[1-read_cnt];
                            DataDriveOut_SI = data_out[0-read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;

                            read_cnt = read_cnt + 1;
                            if (read_cnt == 1)
                            begin
                                read_cnt = 0;
                            end
                        end
                        else
                        begin
                            DataDriveOut_SO = STR2V[7-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8)
                                read_cnt = 0;
                        end
                    end
                    else if (Instruct == RDARG_C_0)
                    begin
                        READ_ALL_REG(read_addr, RDAR_reg);

                        if (QPI_IT)
                        begin
                            data_out_nibble[0]  = RDAR_reg[7:4];
							data_out_nibble[1]  = RDAR_reg[3:0];
							data_out_nibble[2]  = ~RDAR_reg[7:4];
							data_out_nibble[3]  = ~RDAR_reg[3:0];
							{DataDriveOut_Dout[1:0], DataDriveOut_SO, DataDriveOut_SI} = data_out_nibble[read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;

                            read_cnt = read_cnt + 1;							
							if ((ITCRCE && read_cnt == 4) || ~ITCRCE && (read_cnt == 2))
								 read_cnt = 0;	
                        end
                        else
                        begin
						    data_out[7:0]   = RDAR_reg;
							data_outb[7:0]  = ~RDAR_reg;
							if(read_cnt < 8)
							    DataDriveOut_SO = data_out[7-read_cnt];
							else if(read_cnt >= 8)
							    DataDriveOut_SO = data_outb[15-read_cnt];
							read_cnt = read_cnt + 1;
							if ((ITCRCE && read_cnt == 16) || ~ITCRCE && (read_cnt == 8))
								read_cnt = 0;		
                        end
                    end
                end

                if(current_state_event && current_state == PAGE_PG)
                begin
                    if (~PDONE)
                    begin
                        ADDRHILO_PG(AddrLo, AddrHi, Addr);
                        cnt = 0;

						for (i=0;i<wr_cnt;i=i+1)
                        begin
                            memory_features_i0.write_mem_w(
                                    Addr + i -cnt,
                                    -1
                                    );

                            if ((Addr + i) == AddrHi)
                            begin
                                Addr = AddrLo;
                                cnt = i + 1;
                            end
                        end
                    end
                    cnt = 0;
                end

                if (PDONE)
                begin
                    
                    if (((CFR4V[3] == 1'b1)  || (non_industrial_temp == 1'b1)) 
                          && (ECC_ERR > 0))
                    begin
                        STR1V[0] = 1'b1; //RDYBSY
                        STR1V[1] = 1'b1; //WRPGEN
                        STR1V[6] = 1'b1; //PRGERR
                        $display ("WARNING: For non-industrial temperatures ");
                        $display ("it is not allowed to have multi-programming ");
                        $display ("without erasing previously the sector!");
                        $display ("multi-pass programming within the same data unit");
                        $display ("will result in a Program Error.");
                        ECC_ERR = 0;
                    end
                    else
                    begin
                        STR1V[0] = 1'b0; //RDYBSY
                        STR1V[1] = 1'b0; //WRPGEN
                        ECC_ERR = 0;
                    end

					if (QPI_IT || (!QPI_IT && (Instruct == PRPG2_C_1 || Instruct == PRPG2_4_1
						|| Instruct == PRPG3_C_1 || Instruct == PRPG3_4_1)))
					begin
						wr_cnt = wr_cnt + 1;
					end

					for (i=0;i<wr_cnt;i=i+1)
                    begin
                        memory_features_i0.write_mem_w(
                                Addr_tmp + i -cnt,
                                WData[i]
                                    );
						//$display("Model Program: Address: 0x%h   Data:0x%h", Addr_tmp + i -cnt, WData[i]);
                        if ((Addr_tmp + i) == AddrHi)
                        begin
                            Addr_tmp = AddrLo;
                            cnt = i + 1;
                        end
                    end
                end

                if (falling_edge_write)
                begin
                    if ((Instruct == SPEPD_0_0) && ~PRGSUSP_in)
                    begin
                        if (~RES_TO_SUSP_TIME)
                        begin
                            PGSUSP = 1'b1;
                            PGSUSP <= #5 1'b0;
                            PRGSUSP_in = 1'b1;
                        end
                        else
                        begin
                            $display("Minimum for tRS is not satisfied! ",
                                     "PGSP command is ignored");
                        end
                    end
                end
            end

            PG_SUSP:
            begin
                if (QPI_IT)
                begin
                    rd_fast = 1'b1;
                    rd_slow = 1'b0;
                    dual    = 1'b1;
                    ddr     = 1'b0;
                end
                else
                begin
                    rd_fast = 1'b1;
                    rd_slow = 1'b0;
                    dual    = 1'b0;
                    ddr     = 1'b0;
                end

                if (PRGSUSP_out && PRGSUSP_in)
                begin
                    PRGSUSP_in = 1'b0;
                    //The RDYBSY bit in the Status Register will indicate that
                    //the device is ready for another operation.
                    STR1V[0] = 1'b0;
                    //The Program Suspend (PROGMS) bit in the Status Register will
                    //be set to the logical “1” state to indicate that the
                    //program operation has been suspended.
                    STR2V[0] = 1'b1;
                end

                if (oe)
                begin
                    any_read = 1'b1;
                    if (Instruct == RDSR1_0_0)
                    begin
                    //Read Status Register 1
                       if (QPI_IT)
                        begin
							if(read_cnt == 0)
							  data_out[7:0] = STR1V;
							else 
							  data_out[7:0] = ~STR1V;
							for (i=0;i<=5;i=i+1)
							begin
								DataDriveOut_Dout[5-i] = data_out[7-i-read_cnt];
							end
							DataDriveOut_SO = data_out[1-read_cnt];
							DataDriveOut_SI = data_out[0-read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;
							
							read_cnt = read_cnt + 1;
							if (read_cnt == (1 + ITCRCE))
							begin
								read_cnt = 0;
							end							
                        end
                        else
                        begin
							DataDriveOut_SO = STR1Vbbar[15-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8 + 8*ITCRCE)
                                read_cnt = 0;
                        end
                    end
                    else if (Instruct == RDSR2_0_0)
                    begin
                        //Read Status Register 2
                        if (QPI_IT)
                        begin
                            data_out[7:0] = STR2V;
                            for (i=0;i<=5;i=i+1)
                            begin
                                DataDriveOut_Dout[5-i] = data_out[7-i-read_cnt];
                            end
                            DataDriveOut_SO = data_out[1-read_cnt];
                            DataDriveOut_SI = data_out[0-read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;

                            read_cnt = read_cnt + 1;
                            if (read_cnt == 1)
                            begin
                                read_cnt = 0;
                            end
                        end
                        else
                        begin
                            DataDriveOut_SO = STR2V[7-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8)
                                read_cnt = 0;
                        end
                    end
                    else if (Instruct == RDARG_C_0)
                    begin
                        READ_ALL_REG(read_addr, RDAR_reg);

                        if (QPI_IT)
                        begin
                            data_out_nibble[0]  = RDAR_reg[7:4];
							data_out_nibble[1]  = RDAR_reg[3:0];
							data_out_nibble[2]  = ~RDAR_reg[7:4];
							data_out_nibble[3]  = ~RDAR_reg[3:0];
							{DataDriveOut_Dout[1:0], DataDriveOut_SO, DataDriveOut_SI} = data_out_nibble[read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;

                            read_cnt = read_cnt + 1;							
							if ((ITCRCE && read_cnt == 4) || ~ITCRCE && (read_cnt == 2))
								 read_cnt = 0;	
                        end
                        else
                        begin
						    data_out[7:0]   = RDAR_reg;
							data_outb[7:0]  = ~RDAR_reg;
							if(read_cnt < 8)
							    DataDriveOut_SO = data_out[7-read_cnt];
							else if(read_cnt >= 8)
							    DataDriveOut_SO = data_outb[15-read_cnt];
							read_cnt = read_cnt + 1;
							if ((ITCRCE && read_cnt == 16) || ~ITCRCE && (read_cnt == 8))
								read_cnt = 0;		
                        end
                    end
                    else if (Instruct == RDCRC_4_0)
                    begin
                        if (Addr_idcfi <= 3)
                        begin
                            data_out[7:0] = ICRV[8*Addr_idcfi+7 -: 8];
                            if (QPI_IT)
                            begin
                                for (i=0;i<=5;i=i+1)
                                begin
                                    DataDriveOut_Dout[5-i] = data_out[7-i-read_cnt];
                                end
                                DataDriveOut_SO = data_out[1-read_cnt];
                                DataDriveOut_SI = data_out[0-read_cnt];

								if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;
                                
								read_cnt = read_cnt + 1;
                                if (read_cnt == 1)
                                begin
                                    read_cnt = 0;
                                    Addr_idcfi = Addr_idcfi + 1;
                                end
                            end
                        end
                    end
                    else if ((Instruct == RDAY2_C_0) && (~QPI_IT))
                    begin
                        if (pgm_page != read_addr / (PageSize+1))
                        begin											
							if (read_cnt == 0)
							begin
								if( ITCRCE && (crc_sgm_cnt != (sgm_size-1)))
								begin
								   //first_rd_byte = 0;
									ReturnSectorID(sect,read_addr);
									SecAddr = sect;
									READMEM(read_addr,SecAddr);	
									data_out = OutputD;
									GEN_CRC_RD8(data_out);
									//$display("read_addr= 0x%h, OutputD=0x%h, data_out=0x%h, sgm_cnt=%d",read_addr, OutputD, data_out, crc_sgm_cnt );
									crc_sgm_cnt = (crc_sgm_cnt+1)%(sgm_size+1);
								//	->Mev1;
								end
								else if( ITCRCE && (crc_sgm_cnt == (sgm_size-1)))
								begin
									data_out_prev = ~crc_reg8_data;
									//$display("crc_reg8_data= 0x%h, data_out=0x%h, sgm_cnt=%d",crc_reg8_data, data_out, crc_sgm_cnt );
									crc_reg8_data = 8'hFF;
									crc_sgm_cnt = (crc_sgm_cnt+1)%(sgm_size+1);
									-> Mev2;
								end
							end				
							ReturnSectorID(sect,read_addr);
							SecAddr = sect;
							READMEM(read_addr,SecAddr);	
							
							if( ITCRCE && (crc_sgm_cnt == sgm_size))
								 data_out = data_out_prev;
							else
								data_out[7:0] = OutputD;
								
							//if (OutputD !== -1)
							if (data_out !== -1)  //Naim
							begin
								DataDriveOut_SO  = data_out[7-read_cnt];
							end
							else
							begin
								DataDriveOut_SO  = 8'bx;
							end
							read_cnt = read_cnt + 1;
							if (read_cnt == 8)
							begin
								read_cnt = 0;
								if(ITCRCE && (crc_sgm_cnt == sgm_size))
								begin
								   if (read_addr >= AddrRANGE)
										read_addr = 0;
								end
								else
								begin
									if (~CFR4V[4])  //Wrap Disabled
									begin
										if (read_addr == AddrRANGE)
											read_addr = 0;
										else
											read_addr = read_addr + 1;
									end
									else           //Wrap Enabled
									begin
										read_addr = read_addr + 1;

										if (read_addr % WrapLength == 0)
											read_addr = read_addr - WrapLength;
									end
								end
							end						
                        end
                        else
                        begin
                            DataDriveOut_SO  = 8'bxxxxxxxx;
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8)
                            begin
                                read_cnt = 0;

                                if (~CFR4V[4])  //Wrap Disabled
                                begin
                                    if (read_addr == AddrRANGE)
                                        read_addr = 0;
                                    else
                                        read_addr = read_addr + 1;
                                end
                                else           //Wrap Enabled
                                begin
                                    read_addr = read_addr + 1;

                                    if (read_addr % WrapLength == 0)
                                        read_addr = read_addr - WrapLength;
                                end
                            end
                        end
                    end
                end
                else if (oe_z)
                begin
                    if ((Instruct == RDAY1_C_0) || ((Instruct == RDAY1_4_0) && (~QPI_IT)))
                    begin
                        rd_fast = 1'b0;
                        rd_slow = 1'b1;
                        dual    = 1'b0;
                        ddr     = 1'b0;
                    end
                    else
                    begin
                        rd_fast = 1'b1;
                        rd_slow = 1'b0;
                        dual    = 1'b0;
                        ddr     = 1'b0;
                    end
                end

                if (falling_edge_write)
                begin
                    if (Instruct == RSEPD_0_0)
                    begin
                        STR2V[0] = 1'b0; // PROGMS
                        STR1V[0] = 1'b1; // RDYBSY
                        PGRES  = 1'b1;
                        PGRES <= #5 1'b0;
                        RES_TO_SUSP_TIME = 1'b1;
                        RES_TO_SUSP_TIME <= #tdevice_RS 1'b0;//100us
                    end
                    else if (Instruct == CLECC_0_0)
                    begin
                        ECSV[4] = 0;// 2 bits ECC detection
                        ECSV[3] = 0;// 1 bit ECC correction
                        INS0V[1] = 1;
                        INS0V[0] = 1;
                        ECTV = 16'h0000;
                        EATV = 32'h00000000;
                    end
                    else if (Instruct == CLPEF_0_0)
                    begin
                        STR1V[6] = 0;// PRGERR
                        STR1V[5] = 0;// ERSERR
                        STR1V[0] = 0;// RDYBSY
                    end

                    if (Instruct == SRSTE_0_0)
                    begin
                        RESET_EN = 1;
                    end
                    else
                    begin
                        RESET_EN <= 0;
                    end
                end
            end

            OTP_PG:
            begin
                rd_fast = 1'b1;
                rd_slow = 1'b0;
                dual    = 1'b0;
                ddr     = 1'b0;

                if (oe)
                begin
                    any_read = 1'b1;
                    if (Instruct == RDSR1_0_0)
                    begin
                    //Read Status Register 1
                       if (QPI_IT)
                        begin
							if(read_cnt == 0)
							  data_out[7:0] = STR1V;
							else 
							  data_out[7:0] = ~STR1V;
							for (i=0;i<=5;i=i+1)
							begin
								DataDriveOut_Dout[5-i] = data_out[7-i-read_cnt];
							end
							DataDriveOut_SO = data_out[1-read_cnt];
							DataDriveOut_SI = data_out[0-read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;
							
							read_cnt = read_cnt + 1;
							if (read_cnt == (1 + ITCRCE))
							begin
								read_cnt = 0;
							end							
                        end
                        else
                        begin
							DataDriveOut_SO = STR1Vbbar[15-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8 + 8*ITCRCE)
                                read_cnt = 0;
                        end
                    end
                    else if (Instruct == RDSR2_0_0)
                    begin
                        //Read Status Register 2
                        if (QPI_IT)
                        begin
                            data_out[7:0] = STR2V;
                            for (i=0;i<=5;i=i+1)
                            begin
                                DataDriveOut_Dout[5-i] = data_out[7-i-read_cnt];
                            end
                            DataDriveOut_SO = data_out[1-read_cnt];
                            DataDriveOut_SI = data_out[0-read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;

                            read_cnt = read_cnt + 1;
                            if (read_cnt == 1)
                            begin
                                read_cnt = 0;
                            end
                        end
                        else
                        begin
                            DataDriveOut_SO = STR2V[7-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8)
                                read_cnt = 0;
                        end
                    end
                    else if (Instruct == RDARG_C_0)
                    begin
                        READ_ALL_REG(read_addr, RDAR_reg);

                        if (QPI_IT)
                        begin
                            data_out_nibble[0]  = RDAR_reg[7:4];
							data_out_nibble[1]  = RDAR_reg[3:0];
							data_out_nibble[2]  = ~RDAR_reg[7:4];
							data_out_nibble[3]  = ~RDAR_reg[3:0];
							{DataDriveOut_Dout[1:0], DataDriveOut_SO, DataDriveOut_SI} = data_out_nibble[read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;
                            
							read_cnt = read_cnt + 1;							
							if ((ITCRCE && read_cnt == 4) || ~ITCRCE && (read_cnt == 2))
								 read_cnt = 0;	
                        end
                        else
                        begin
						    data_out[7:0]   = RDAR_reg;
							data_outb[7:0]  = ~RDAR_reg;
							if(read_cnt < 8)
							    DataDriveOut_SO = data_out[7-read_cnt];
							else if(read_cnt >= 8)
							    DataDriveOut_SO = data_outb[15-read_cnt];
							read_cnt = read_cnt + 1;
							if ((ITCRCE && read_cnt == 16) || ~ITCRCE && (read_cnt == 8))
								read_cnt = 0;		
                        end
                    end
                end

                if(current_state_event && current_state == OTP_PG)
                begin
                    if (~PDONE)
                    begin
						for (i=0; i<=wr_cnt; i=i+1)
						begin
							OTPMem[Addr + i] = -1;
						end
						
						crc_drp_cnt = 0;
                    end
                end

                if (PDONE)
                begin
                    if (((CFR4V[3] == 1'b1)  || (non_industrial_temp == 1'b1)) 
                          && (ECC_ERR > 0) )
                    begin
                        STR1V[0] = 1'b1; //RDYBSY
                        STR1V[1] = 1'b1; //WRPGEN
                        STR1V[6] = 1'b1; //PRGERR
                        ECC_ERR = 0;
                        $display ("WARNING: For non-industrial temperatures ");
                        $display ("it is not allowed to have multi-programming ");
                        $display ("without erasing previously the sector!");
                        $display ("multi-pass programming within the same sector will result in a Program Error.");
                    end
                    else
                    begin
                        STR1V[0] = 1'b0; //RDYBSY
                        STR1V[1] = 1'b0; //WRPGEN
                        ECC_ERR = 0;
                    end

                    for (i=0;i<=wr_cnt;i=i+1)
                    begin
                        OTPMem[Addr + i] = WData[i];
                    end
                    LOCK_BYTE1 = OTPMem[16];
                    LOCK_BYTE2 = OTPMem[17];
                    LOCK_BYTE3 = OTPMem[18];
                    LOCK_BYTE4 = OTPMem[19];
                end
            end

            CRC_Calc:
            begin
                if (QPI_IT)
                begin
                    rd_fast = 1'b1;
                    rd_slow = 1'b0;
                    dual    = 1'b1;
                    ddr     = 1'b0;
                end
                else
                begin
                    rd_fast = 1'b1;
                    rd_slow = 1'b0;
                    dual    = 1'b0;
                    ddr     = 1'b0;
                end

                if (oe)
                begin
                    any_read = 1'b1;
                    if (Instruct == RDSR1_0_0)
                    begin
                       if (QPI_IT)
                        begin
							if(read_cnt == 0)
							  data_out[7:0] = STR1V;
							else 
							  data_out[7:0] = ~STR1V;
							for (i=0;i<=5;i=i+1)
							begin
								DataDriveOut_Dout[5-i] = data_out[7-i-read_cnt];
							end
							DataDriveOut_SO = data_out[1-read_cnt];
							DataDriveOut_SI = data_out[0-read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;
							
							read_cnt = read_cnt + 1;
							if (read_cnt == (1 + ITCRCE))
							begin
								read_cnt = 0;
							end							
                        end
                        else
                        begin
							DataDriveOut_SO = STR1Vbbar[15-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8 + 8*ITCRCE)
                                read_cnt = 0;
                        end
                    end
                end

                CRC_ACT      = 1'b1;
                CRC_RD_SETUP =  1'b1;

                if (rising_edge_CRCDONE)
                begin
                    crc_out = 32'h00000000;
                    for (i=CRC_Start_Addr_reg;i<=CRC_End_Addr_reg;i=i+1)
                    begin
                        memory_features_i0.read_mem_w(
                        mem_data,
                        i
                        );
                        crc_in = mem_data;
                        for (j=15;j>=0;j=j-1)
                        begin
                            crc_tmp = crc_out[31] ^ crc_in[j];

                            crc_out[31] = crc_out[30];
                            crc_out[30] = crc_out[29];
                            crc_out[29] = crc_out[28];
                            crc_out[28] = crc_out[27] ^ crc_tmp;
                            crc_out[27] = crc_out[26] ^ crc_tmp;
                            crc_out[26] = crc_out[25] ^ crc_tmp;
                            crc_out[25] = crc_out[24] ^ crc_tmp;
                            crc_out[24] = crc_out[23];
                            crc_out[23] = crc_out[22] ^ crc_tmp;
                            crc_out[22] = crc_out[21] ^ crc_tmp;
                            crc_out[21] = crc_out[20];
                            crc_out[20] = crc_out[19] ^ crc_tmp;
                            crc_out[19] = crc_out[18] ^ crc_tmp;
                            crc_out[18] = crc_out[17] ^ crc_tmp;
                            crc_out[17] = crc_out[16];
                            crc_out[16] = crc_out[15];
                            crc_out[15] = crc_out[14];
                            crc_out[14] = crc_out[13] ^ crc_tmp;
                            crc_out[13] = crc_out[12] ^ crc_tmp;
                            crc_out[12] = crc_out[11];
                            crc_out[11] = crc_out[10] ^ crc_tmp;
                            crc_out[10] = crc_out[9] ^ crc_tmp;
                            crc_out[9] = crc_out[8] ^ crc_tmp;
                            crc_out[8] = crc_out[7] ^ crc_tmp;
                            crc_out[7] = crc_out[6];
                            crc_out[6] = crc_out[5] ^ crc_tmp;
                            crc_out[5] = crc_out[4];
                            crc_out[4] = crc_out[3];
                            crc_out[3] = crc_out[2];
                            crc_out[2] = crc_out[1];
                            crc_out[1] = crc_out[0];
                            crc_out[0] = crc_tmp;
                        end

						/*
						crc_out = crc_out ^ crc_in;

						for (j=31; j>=0; j=j-1)
						begin
							if (crc_out[31]) crc_out = ((crc_out << 1) ^ 32'h1EDC6F41);
							else			 crc_out = (crc_out << 1);
						end
						*/
                    end
                    DCRV = crc_out;
                    STR1V[0] = 1'b0; // RDYBSY
                end
            end

            CRC_SUSP:
            begin
                if (QPI_IT)
                begin
                    rd_fast = 1'b1;
                    rd_slow = 1'b0;
                    dual    = 1'b1;
                    ddr     = 1'b0;
                end
                else
                begin
                    rd_fast = 1'b1;
                    rd_slow = 1'b0;
                    dual    = 1'b0;
                    ddr     = 1'b0;
                end

                if (sSTART_T1 && START_T1_in)
                begin
                    START_T1_in = 1'b0;
                    //The RDYBSY bit in the Status Register will indicate that
                    //the device is ready for another operation.
                    STR1V[0] = 1'b0;
                    //The CRC Suspend (DICRCS) bit in the Status Register will
                    //be set to the logical “1” state to indicate that the
                    //CRC operation has been suspended.
                    STR2V[4] = 1'b1;
                end

                if (oe)
                begin
                    any_read = 1'b1;
                    if (Instruct == RDSR1_0_0)
                    begin
                    //Read Status Register 1
                       if (QPI_IT)
                        begin
							if(read_cnt == 0)
							  data_out[7:0] = STR1V;
							else 
							  data_out[7:0] = ~STR1V;
							for (i=0;i<=5;i=i+1)
							begin
								DataDriveOut_Dout[5-i] = data_out[7-i-read_cnt];
							end
							DataDriveOut_SO = data_out[1-read_cnt];
							DataDriveOut_SI = data_out[0-read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;
							
							read_cnt = read_cnt + 1;
							if (read_cnt == (1 + ITCRCE))
							begin
								read_cnt = 0;
							end							
                        end
                        else
                        begin
							DataDriveOut_SO = STR1Vbbar[15-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8 + 8*ITCRCE)
                                read_cnt = 0;
                        end
                    end
                    else if (Instruct == RDSR2_0_0)
                    begin
                        //Read Status Register 2
                        if (QPI_IT)
                        begin
                            data_out[7:0] = STR2V;
                            for (i=0;i<=5;i=i+1)
                            begin
                                DataDriveOut_Dout[5-i] = data_out[7-i-read_cnt];
                            end
                            DataDriveOut_SO = data_out[1-read_cnt];
                            DataDriveOut_SI = data_out[0-read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;

                            read_cnt = read_cnt + 1;
                            if (read_cnt == 1)
                            begin
                                read_cnt = 0;
                            end
                        end
                        else
                        begin
                            DataDriveOut_SO = STR2V[7-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8)
                                read_cnt = 0;
                        end
                    end
                    else if (Instruct == RDARG_C_0)
                    begin
                        READ_ALL_REG(read_addr, RDAR_reg);

                        if (QPI_IT)
                        begin
                            data_out_nibble[0]  = RDAR_reg[7:4];
							data_out_nibble[1]  = RDAR_reg[3:0];
							data_out_nibble[2]  = ~RDAR_reg[7:4];
							data_out_nibble[3]  = ~RDAR_reg[3:0];
							{DataDriveOut_Dout[1:0], DataDriveOut_SO, DataDriveOut_SI} = data_out_nibble[read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;

                            read_cnt = read_cnt + 1;							
							if ((ITCRCE && read_cnt == 4) || ~ITCRCE && (read_cnt == 2))
								 read_cnt = 0;	
                        end
                        else
                        begin
						    data_out[7:0]   = RDAR_reg;
							data_outb[7:0]  = ~RDAR_reg;
							if(read_cnt < 8)
							    DataDriveOut_SO = data_out[7-read_cnt];
							else if(read_cnt >= 8)
							    DataDriveOut_SO = data_outb[15-read_cnt];
							read_cnt = read_cnt + 1;
							if ((ITCRCE && read_cnt == 16) || ~ITCRCE && (read_cnt == 8))
								read_cnt = 0;		
                        end
                    end
                    else if ((Instruct == RDAY2_C_0) && (~QPI_IT))
                    begin

                        if (pgm_page != read_addr / (PageSize+1))
                        begin
							if (read_cnt == 0)
							begin
								if( ITCRCE && (crc_sgm_cnt != (sgm_size-1)))
								begin
								   //first_rd_byte = 0;
									ReturnSectorID(sect,read_addr);
									SecAddr = sect;
									READMEM(read_addr,SecAddr);	
									data_out = OutputD;
									GEN_CRC_RD8(data_out);
									//$display("read_addr= 0x%h, OutputD=0x%h, data_out=0x%h, sgm_cnt=%d",read_addr, OutputD, data_out, crc_sgm_cnt );
									crc_sgm_cnt = (crc_sgm_cnt+1)%(sgm_size+1);
								//	->Mev1;
								end
								else if( ITCRCE && (crc_sgm_cnt == (sgm_size-1)))
								begin
									data_out_prev = ~crc_reg8_data;
									//$display("crc_reg8_data= 0x%h, data_out=0x%h, sgm_cnt=%d",crc_reg8_data, data_out, crc_sgm_cnt );
									crc_reg8_data = 8'hFF;
									crc_sgm_cnt = (crc_sgm_cnt+1)%(sgm_size+1);
									-> Mev2;
								end
							end				
							ReturnSectorID(sect,read_addr);
							SecAddr = sect;
							READMEM(read_addr,SecAddr);	
							
							if( ITCRCE && (crc_sgm_cnt == sgm_size))
								 data_out = data_out_prev;
							else
								data_out[7:0] = OutputD;
								
							//if (OutputD !== -1)
							if (data_out !== -1)  //Naim
							begin
								DataDriveOut_SO  = data_out[7-read_cnt];
							end
							else
							begin
								DataDriveOut_SO  = 8'bx;
							end
							read_cnt = read_cnt + 1;
							if (read_cnt == 8)
							begin
								read_cnt = 0;
								if(ITCRCE && (crc_sgm_cnt == sgm_size))
								begin
								   if (read_addr >= AddrRANGE)
										read_addr = 0;
								end
								else
								begin
									if (~CFR4V[4])  //Wrap Disabled
									begin
										if (read_addr == AddrRANGE)
											read_addr = 0;
										else
											read_addr = read_addr + 1;
									end
									else           //Wrap Enabled
									begin
										read_addr = read_addr + 1;

										if (read_addr % WrapLength == 0)
											read_addr = read_addr - WrapLength;
									end
								end
							end													
                        end
                        else
                        begin
                            DataDriveOut_SO  = 8'bxxxxxxxx;
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8)
                            begin
                                read_cnt = 0;

                                if (~CFR4V[4])  //Wrap Disabled
                                begin
                                    if (read_addr == AddrRANGE)
                                        read_addr = 0;
                                    else
                                        read_addr = read_addr + 1;
                                end
                                else           //Wrap Enabled
                                begin
                                    read_addr = read_addr + 1;

                                    if (read_addr % WrapLength == 0)
                                        read_addr = read_addr - WrapLength;
                                end
                            end
                        end
                    end
                end
                else if (oe_z)
                begin
                    if ((Instruct == RDAY1_C_0) || ((Instruct == RDAY1_4_0) && (~QPI_IT)))
                    begin
                        rd_fast = 1'b0;
                        rd_slow = 1'b1;
                        dual    = 1'b0;
                        ddr     = 1'b0;
                    end
                    else
                    begin
                        rd_fast = 1'b1;
                        rd_slow = 1'b0;
                        dual    = 1'b0;
                        ddr     = 1'b0;
                    end
                end

                if (falling_edge_write)
                begin
                    if (Instruct == RSEPD_0_0)
                    begin
                        STR2V[4] = 1'b0; // DICRCS
                        STR1V[0] = 1'b1; // RDYBSY
                        CRCRES  = 1'b1;
                        CRCRES <= #5 1'b0;
                        RES_TO_SUSP_TIME = 1'b1;
                        RES_TO_SUSP_TIME <= #tdevice_CRCRL 1'b0;// 5us
                    end

                    if (Instruct == SRSTE_0_0)
                    begin
                        RESET_EN = 1;
                    end
                    else
                    begin
                        RESET_EN <= 0;
                    end
                end
            end

            SECTOR_ERS:
            begin
                if (QPI_IT)
                begin
                    rd_fast = 1'b1;
                    rd_slow = 1'b0;
                    dual    = 1'b1;
                    ddr     = 1'b0;
                end
                else
                begin
                    rd_fast = 1'b1;
                    rd_slow = 1'b0;
                    dual    = 1'b0;
                    ddr     = 1'b0;
                end

                if (oe)
                begin
                    any_read = 1'b1;
                    if (Instruct == RDSR1_0_0)
                    begin
                    //Read Status Register 1
                       if (QPI_IT)
                        begin
							if(read_cnt == 0)
							  data_out[7:0] = STR1V;
							else 
							  data_out[7:0] = ~STR1V;
							for (i=0;i<=5;i=i+1)
							begin
								DataDriveOut_Dout[5-i] = data_out[7-i-read_cnt];
							end
							DataDriveOut_SO = data_out[1-read_cnt];
							DataDriveOut_SI = data_out[0-read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;
							
							read_cnt = read_cnt + 1;
							if (read_cnt == (1 + ITCRCE))
							begin
								read_cnt = 0;
							end							
                        end
                        else
                        begin
							DataDriveOut_SO = STR1Vbbar[15-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8 + 8*ITCRCE)
                                read_cnt = 0;
                        end
                    end
                    else if (Instruct == RDSR2_0_0)
                    begin
                        //Read Status Register 2
                        if (QPI_IT)
                        begin
                            data_out[7:0] = STR2V;
                            for (i=0;i<=5;i=i+1)
                            begin
                                DataDriveOut_Dout[5-i] = data_out[7-i-read_cnt];
                            end
                            DataDriveOut_SO = data_out[1-read_cnt];
                            DataDriveOut_SI = data_out[0-read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;

                            read_cnt = read_cnt + 1;
                            if (read_cnt == 1)
                            begin
                                read_cnt = 0;
                            end
                        end
                        else
                        begin
                            DataDriveOut_SO = STR2V[7-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8)
                                read_cnt = 0;
                        end
                    end
                    else if (Instruct == RDARG_C_0)
                    begin
                        READ_ALL_REG(read_addr, RDAR_reg);

                        if (QPI_IT)
                        begin
                            data_out_nibble[0]  = RDAR_reg[7:4];
							data_out_nibble[1]  = RDAR_reg[3:0];
							data_out_nibble[2]  = ~RDAR_reg[7:4];
							data_out_nibble[3]  = ~RDAR_reg[3:0];
							{DataDriveOut_Dout[1:0], DataDriveOut_SO, DataDriveOut_SI} = data_out_nibble[read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;
                            
							read_cnt = read_cnt + 1;							
							if ((ITCRCE && read_cnt == 4) || ~ITCRCE && (read_cnt == 2))
								 read_cnt = 0;	
                        end
                        else
                        begin
						    data_out[7:0]   = RDAR_reg;
							data_outb[7:0]  = ~RDAR_reg;
							if(read_cnt < 8)
							    DataDriveOut_SO = data_out[7-read_cnt];
							else if(read_cnt >= 8)
							    DataDriveOut_SO = data_outb[15-read_cnt];
							read_cnt = read_cnt + 1;
							if ((ITCRCE && read_cnt == 16) || ~ITCRCE && (read_cnt == 8))
								read_cnt = 0;		
                        end
                    end
                end

                if(current_state_event && current_state == SECTOR_ERS) //ERO04_C_0 & ERO04_4_0
                begin
                    if (~EDONE)
                    begin
                        memory_features_i0.erase_mem_w(
                                Address_erase,
                                (Address_erase + SecSize256)
                         );

						ReturnSectorID(SectorErased,Address_erase);
                        corrupt_Sec[SectorErased] = 1;
						ERS_nosucc[SectorErased] = 1;
                    end
                end

                if (EDONE == 1)
                begin
                    STR1V[0] = 1'b0; //RDYBSY
                    STR1V[1] = 1'b0; //WRPGEN

					ReturnSectorID(SectorErased,Address_erase);

                    ERS_nosucc[SectorErased] = 1'b0;

                    // Increment Sector Erase Count register for a given Sector
                    SECVAL_in[SectorErased] = SECVAL_in[SectorErased] + 23'h000001;

                    // Erase multi-pass sector flags register
                    MPASSREG[SectorErased] = 1'b0;
                    corrupt_Sec[SectorErased] = 0;
                end

                if (falling_edge_write)
                begin
                    if ((Instruct == SPEPD_0_0) && ~ERSSUSP_in)
                    begin
                        if (~RES_TO_SUSP_TIME)
                        begin
                            ESUSP      = 1'b1;
                            ESUSP     <= #5 1'b0;
                            ERSSUSP_in = 1'b1;
                        end
                        else
                        begin
                            $display("Minimum for tRS is not satisfied! ",
                                     "PGSP command is ignored");
                        end
                    end
                end
            end

			HALF_BLK_ERS:
			begin
                if (QPI_IT)
                begin
                    rd_fast = 1'b1;
                    rd_slow = 1'b0;
                    dual    = 1'b1;
                    ddr     = 1'b0;
                end
                else
                begin
                    rd_fast = 1'b1;
                    rd_slow = 1'b0;
                    dual    = 1'b0;
                    ddr     = 1'b0;
                end

                if (oe)
                begin
                    any_read = 1'b1;
                    if (Instruct == RDSR1_0_0)
                    begin
                    //Read Status Register 1
                       if (QPI_IT)
                        begin
							if(read_cnt == 0)
							  data_out[7:0] = STR1V;
							else 
							  data_out[7:0] = ~STR1V;
							for (i=0;i<=5;i=i+1)
							begin
								DataDriveOut_Dout[5-i] = data_out[7-i-read_cnt];
							end
							DataDriveOut_SO = data_out[1-read_cnt];
							DataDriveOut_SI = data_out[0-read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;
							
							read_cnt = read_cnt + 1;
							if (read_cnt == (1 + ITCRCE))
							begin
								read_cnt = 0;
							end							
                        end
                        else
                        begin
							DataDriveOut_SO = STR1Vbbar[15-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8 + 8*ITCRCE)
                                read_cnt = 0;
                        end
                    end
                    else if (Instruct == RDSR2_0_0)
                    begin
                        //Read Status Register 2
                        if (QPI_IT)
                        begin
                            data_out[7:0] = STR2V;
                            for (i=0;i<=5;i=i+1)
                            begin
                                DataDriveOut_Dout[5-i] = data_out[7-i-read_cnt];
                            end
                            DataDriveOut_SO = data_out[1-read_cnt];
                            DataDriveOut_SI = data_out[0-read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;

                            read_cnt = read_cnt + 1;
                            if (read_cnt == 1)
                            begin
                                read_cnt = 0;
                            end
                        end
                        else
                        begin
                            DataDriveOut_SO = STR2V[7-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8)
                                read_cnt = 0;
                        end
                    end
                    else if (Instruct == RDARG_C_0)
                    begin
                        READ_ALL_REG(read_addr, RDAR_reg);

                        if (QPI_IT)
                        begin
                            data_out_nibble[0]  = RDAR_reg[7:4];
							data_out_nibble[1]  = RDAR_reg[3:0];
							data_out_nibble[2]  = ~RDAR_reg[7:4];
							data_out_nibble[3]  = ~RDAR_reg[3:0];
							{DataDriveOut_Dout[1:0], DataDriveOut_SO, DataDriveOut_SI} = data_out_nibble[read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;
                            
							read_cnt = read_cnt + 1;							
							if ((ITCRCE && read_cnt == 4) || ~ITCRCE && (read_cnt == 2))
								 read_cnt = 0;	
                        end
                        else
                        begin
						    data_out[7:0]   = RDAR_reg;
							data_outb[7:0]  = ~RDAR_reg;
							if(read_cnt < 8)
							    DataDriveOut_SO = data_out[7-read_cnt];
							else if(read_cnt >= 8)
							    DataDriveOut_SO = data_outb[15-read_cnt];
							read_cnt = read_cnt + 1;
							if ((ITCRCE && read_cnt == 16) || ~ITCRCE && (read_cnt == 8))
								read_cnt = 0;		
                        end
                    end
                end

                if(current_state_event && current_state == HALF_BLK_ERS) //ERO32_C_0 & ERO32_4_0
                begin
                    if (~EDONE)
                    begin
						for (i=0; i<8; i=i+1)
                        begin
                        	memory_features_i0.erase_mem_w(
                            	Address_erase + i*(SecSize256+1),
								(Address_erase + i*(SecSize256+1) + SecSize256)
                        	);

							ReturnSectorID(SectorErased,(Address_erase + i*(SecSize256+1)));
							corrupt_Sec[SectorErased] = 1;
							ERS_nosucc[SectorErased] = 1;
                        end
                    end
                end

                if (EDONE == 1)
                begin
                    STR1V[0] = 1'b0; // RDYBSY
                    STR1V[1] = 1'b0; // WRPGEN

					for (i=0; i<8; i=i+1)
					begin
						ReturnSectorID(SectorErased,(Address_erase + i*(SecSize256+1)));

						//Set Erase no success to 0 for all the involved sectors
						ERS_nosucc[SectorErased] = 1'b0;

						//Increment Sector Erase Count register for a given sector
						SECVAL_in[SectorErased] = SECVAL_in[SectorErased] + 23'h000001;

						//Erase multi-pass sector flags register
						MPASSREG[SectorErased] = 1'b0;
						corrupt_Sec[SectorErased] = 0;
					end
                end

				if (falling_edge_write)
                begin
                    if ((Instruct == SPEPD_0_0) && ~ERSSUSP_in)
                    begin
                        if (~RES_TO_SUSP_TIME)
                        begin
                            ESUSP      = 1'b1;
                            ESUSP     <= #5 1'b0;
                            ERSSUSP_in = 1'b1;
                        end
                        else
                        begin
                            $display("Minimum for tRS is not satisfied! ",
                                     "PGSP command is ignored");
                        end
                    end
                end
            end

			BLK_ERS:
			begin
                if (QPI_IT)
                begin
                    rd_fast = 1'b1;
                    rd_slow = 1'b0;
                    dual    = 1'b1;
                    ddr     = 1'b0;
                end
                else
                begin
                    rd_fast = 1'b1;
                    rd_slow = 1'b0;
                    dual    = 1'b0;
                    ddr     = 1'b0;
                end

                if (oe)
                begin
                    any_read = 1'b1;
                    if (Instruct == RDSR1_0_0)
                    begin
                    //Read Status Register 1
                       if (QPI_IT)
                        begin
							if(read_cnt == 0)
							  data_out[7:0] = STR1V;
							else 
							  data_out[7:0] = ~STR1V;
							for (i=0;i<=5;i=i+1)
							begin
								DataDriveOut_Dout[5-i] = data_out[7-i-read_cnt];
							end
							DataDriveOut_SO = data_out[1-read_cnt];
							DataDriveOut_SI = data_out[0-read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;
							
							read_cnt = read_cnt + 1;
							if (read_cnt == (1 + ITCRCE))
							begin
								read_cnt = 0;
							end							
                        end
                        else
                        begin
							DataDriveOut_SO = STR1Vbbar[15-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8 + 8*ITCRCE)
                                read_cnt = 0;
                        end
                    end
                    else if (Instruct == RDSR2_0_0)
                    begin
                        //Read Status Register 2
                        if (QPI_IT)
                        begin
                            data_out[7:0] = STR2V;
                            for (i=0;i<=5;i=i+1)
                            begin
                                DataDriveOut_Dout[5-i] = data_out[7-i-read_cnt];
                            end
                            DataDriveOut_SO = data_out[1-read_cnt];
                            DataDriveOut_SI = data_out[0-read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;

                            read_cnt = read_cnt + 1;
                            if (read_cnt == 1)
                            begin
                                read_cnt = 0;
                            end
                        end
                        else
                        begin
                            DataDriveOut_SO = STR2V[7-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8)
                                read_cnt = 0;
                        end
                    end
                    else if (Instruct == RDARG_C_0)
                    begin
                        READ_ALL_REG(read_addr, RDAR_reg);

                        if (QPI_IT)
                        begin
                            data_out_nibble[0]  = RDAR_reg[7:4];
							data_out_nibble[1]  = RDAR_reg[3:0];
							data_out_nibble[2]  = ~RDAR_reg[7:4];
							data_out_nibble[3]  = ~RDAR_reg[3:0];
							{DataDriveOut_Dout[1:0], DataDriveOut_SO, DataDriveOut_SI} = data_out_nibble[read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;
                            
							read_cnt = read_cnt + 1;							
							if ((ITCRCE && read_cnt == 4) || ~ITCRCE && (read_cnt == 2))
								 read_cnt = 0;	
                        end
                        else
                        begin
						    data_out[7:0]   = RDAR_reg;
							data_outb[7:0]  = ~RDAR_reg;
							if(read_cnt < 8)
							    DataDriveOut_SO = data_out[7-read_cnt];
							else if(read_cnt >= 8)
							    DataDriveOut_SO = data_outb[15-read_cnt];
							read_cnt = read_cnt + 1;
							if ((ITCRCE && read_cnt == 16) || ~ITCRCE && (read_cnt == 8))
								read_cnt = 0;		
                        end
                    end
                end

                if(current_state_event && current_state == BLK_ERS) //ERO64_C_0 & ERO64_4_0
                begin
                    if (~EDONE)
                    begin
						for (i=0; i<16; i=i+1)
						begin
                        	memory_features_i0.erase_mem_w(
                                Address_erase + i*(SecSize256+1),
                                (Address_erase + i*(SecSize256+1) + SecSize256)
                         	);

							ReturnSectorID(SectorErased,Address_erase + i*(SecSize256+1));
                        	corrupt_Sec[SectorErased] = 1;
							ERS_nosucc[SectorErased] = 1;
						end
                    end
                end

                if (EDONE == 1)
                begin
                    STR1V[0] = 1'b0; //RDYBSY
                    STR1V[1] = 1'b0; //WRPGEN

					for (i=0; i<16; i=i+1)
					begin
						ReturnSectorID(SectorErased,(Address_erase + i*(SecSize256+1)));

						//Set Erase no success to 0 for all the involved sectors
                    	ERS_nosucc[SectorErased] = 1'b0;

                    	// Increment Sector Erase Count register for a given Sector
                    	SECVAL_in[SectorErased] = SECVAL_in[SectorErased] + 23'h000001;

                    	// Erase multi-pass sector flags register
                    	MPASSREG[SectorErased] = 1'b0;
                    	corrupt_Sec[SectorErased] = 0;
					end
                end

				if (falling_edge_write)
                begin
                    if ((Instruct == SPEPD_0_0) && ~ERSSUSP_in)
                    begin
                        if (~RES_TO_SUSP_TIME)
                        begin
                            ESUSP      = 1'b1;
                            ESUSP     <= #5 1'b0;
                            ERSSUSP_in = 1'b1;
                        end
                        else
                        begin
                            $display("Minimum for tRS is not satisfied! ",
                                     "PGSP command is ignored");
                        end
                    end
                end
            end

			BULK_ERS:
			begin
                if (QPI_IT)
                begin
                    rd_fast = 1'b1;
                    rd_slow = 1'b0;
                    dual    = 1'b1;
                    ddr     = 1'b0;
                end
                else
                begin
                    rd_fast = 1'b1;
                    rd_slow = 1'b0;
                    dual    = 1'b0;
                    ddr     = 1'b0;
                end

                if (oe)
                begin
                    any_read = 1'b1;
                    if (Instruct == RDSR1_0_0)
                    begin
                    //Read Status Register 1
                       if (QPI_IT)
                        begin
							if(read_cnt == 0)
							  data_out[7:0] = STR1V;
							else 
							  data_out[7:0] = ~STR1V;
							for (i=0;i<=5;i=i+1)
							begin
								DataDriveOut_Dout[5-i] = data_out[7-i-read_cnt];
							end
							DataDriveOut_SO = data_out[1-read_cnt];
							DataDriveOut_SI = data_out[0-read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;
							
							read_cnt = read_cnt + 1;
							if (read_cnt == (1 + ITCRCE))
							begin
								read_cnt = 0;
							end							
                        end
                        else
                        begin
							DataDriveOut_SO = STR1Vbbar[15-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8 + 8*ITCRCE)
                                read_cnt = 0;
                        end
                    end
                    else if (Instruct == RDSR2_0_0)
                    begin
                        //Read Status Register 2
                        if (QPI_IT)
                        begin
                            data_out[7:0] = STR2V;
                            for (i=0;i<=5;i=i+1)
                            begin
                                DataDriveOut_Dout[5-i] = data_out[7-i-read_cnt];
                            end
                            DataDriveOut_SO = data_out[1-read_cnt];
                            DataDriveOut_SI = data_out[0-read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;

                            read_cnt = read_cnt + 1;
                            if (read_cnt == 1)
                            begin
                                read_cnt = 0;
                            end
                        end
                        else
                        begin
                            DataDriveOut_SO = STR2V[7-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8)
                                read_cnt = 0;
                        end
                    end
                    else if (Instruct == RDARG_C_0)
                    begin
                        READ_ALL_REG(read_addr, RDAR_reg);

                        if (QPI_IT)
                        begin
                            data_out_nibble[0]  = RDAR_reg[7:4];
							data_out_nibble[1]  = RDAR_reg[3:0];
							data_out_nibble[2]  = ~RDAR_reg[7:4];
							data_out_nibble[3]  = ~RDAR_reg[3:0];
							{DataDriveOut_Dout[1:0], DataDriveOut_SO, DataDriveOut_SI} = data_out_nibble[read_cnt];
							
							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;
                            
							read_cnt = read_cnt + 1;							
							if ((ITCRCE && read_cnt == 4) || ~ITCRCE && (read_cnt == 2))
								 read_cnt = 0;	
                        end
                        else
                        begin
						    data_out[7:0]   = RDAR_reg;
							data_outb[7:0]  = ~RDAR_reg;
							if(read_cnt < 8)
							    DataDriveOut_SO = data_out[7-read_cnt];
							else if(read_cnt >= 8)
							    DataDriveOut_SO = data_outb[15-read_cnt];
							read_cnt = read_cnt + 1;
							if ((ITCRCE && read_cnt == 16) || ~ITCRCE && (read_cnt == 8))
								read_cnt = 0;		
                        end
                    end
                end

                if(current_state_event && current_state == BULK_ERS) //ERCHP_0_0_60 & ERCHP_0_0_C7
                begin
                    if (~EDONE)
                    begin
						for (i=0; i<=SecNumHyb; i=i+1)
						begin
							if (PPB_bits[i] == 1 && DYB_bits[i] == 1)
							begin
                        		memory_features_i0.erase_mem_w(
                                	Address_erase + i*(SecSize256+1),
                                	(Address_erase + i*(SecSize256+1) + SecSize256)
                         		);

								corrupt_Sec[i] = 1;
								ERS_nosucc[i] = 1;
							end
						end
                    end
                end

                if (EDONE == 1)
                begin
                    STR1V[0] = 1'b0; //RDYBSY
                    STR1V[1] = 1'b0; //WRPGEN

					for (i=0; i<=SecNumHyb; i=i+1)
					begin
						ReturnSectorID(SectorErased,(i*(SecSize256+1)));

						//Set Erase no success to 0 for all the involved sectors
                    	ERS_nosucc[SectorErased] = 1'b0;

                    	// Increment Sector Erase Count register for a given Sector
                    	SECVAL_in[SectorErased] = SECVAL_in[SectorErased] + 23'h000001;

                    	// Erase multi-pass sector flags register
                    	MPASSREG[SectorErased] = 1'b0;
                    	corrupt_Sec[SectorErased] = 0;
					end
                end

				if (falling_edge_write)
                begin
                    if ((Instruct == SPEPD_0_0) && ~ERSSUSP_in)
                    begin
                        if (~RES_TO_SUSP_TIME)
                        begin
                            ESUSP      = 1'b1;
                            ESUSP     <= #5 1'b0;
                            ERSSUSP_in = 1'b1;
                        end
                        else
                        begin
                            $display("Minimum for tRS is not satisfied! ",
                                     "PGSP command is ignored");
                        end
                    end
                end
            end

            ERS_SUSP:
            begin
                if (QPI_IT)
                begin
                    rd_fast = 1'b1;
                    rd_slow = 1'b0;
                    dual    = 1'b1;
                    ddr     = 1'b0;
                end
                else
                begin
                    rd_fast = 1'b1;
                    rd_slow = 1'b0;
                    dual    = 1'b0;
                    ddr     = 1'b0;
                end

                if (ERSSUSP_out)
                begin
                    ERSSUSP_in = 0;
                    //The Erase Suspend (ERASES) bit in the Status Register will
                    //be set to the logical “1” state to indicate that the
                    //erase operation has been suspended.
                    STR2V[1] = 1'b1;
                    //The RDYBSY bit in the Status Register will indicate that
                    //the device is ready for another operation.
                    STR1V[0] = 1'b0;
                end

                if (oe)
                begin
                    any_read = 1'b1;
                    if (Instruct == RDSR1_0_0)
                    begin
                    //Read Status Register 1
                       if (QPI_IT)
                        begin
							if(read_cnt == 0)
							  data_out[7:0] = STR1V;
							else 
							  data_out[7:0] = ~STR1V;
							for (i=0;i<=5;i=i+1)
							begin
								DataDriveOut_Dout[5-i] = data_out[7-i-read_cnt];
							end
							DataDriveOut_SO = data_out[1-read_cnt];
							DataDriveOut_SI = data_out[0-read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;
							
							read_cnt = read_cnt + 1;
							if (read_cnt == (1 + ITCRCE))
							begin
								read_cnt = 0;
							end							
                        end
                        else
                        begin
							DataDriveOut_SO = STR1Vbbar[15-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8 + 8*ITCRCE)
                                read_cnt = 0;
                        end
                    end
                    else if (Instruct == RDSR2_0_0)
                    begin
                        //Read Status Register 2
                        if (QPI_IT)
                        begin
                            data_out[7:0] = STR2V;
                            for (i=0;i<=5;i=i+1)
                            begin
                                DataDriveOut_Dout[5-i] = data_out[7-i-read_cnt];
                            end
                            DataDriveOut_SO = data_out[1-read_cnt];
                            DataDriveOut_SI = data_out[0-read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;

                            read_cnt = read_cnt + 1;
                            if (read_cnt == 1)
                            begin
                                read_cnt = 0;
                            end
                        end
                        else
                        begin
                            DataDriveOut_SO = STR2V[7-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8)
                                read_cnt = 0;
                        end
                    end
                    else if (Instruct == RDARG_C_0)
                    begin
                        READ_ALL_REG(read_addr, RDAR_reg);

                        if (QPI_IT)
                        begin
                            data_out_nibble[0]  = RDAR_reg[7:4];
							data_out_nibble[1]  = RDAR_reg[3:0];
							data_out_nibble[2]  = ~RDAR_reg[7:4];
							data_out_nibble[3]  = ~RDAR_reg[3:0];
							{DataDriveOut_Dout[1:0], DataDriveOut_SO, DataDriveOut_SI} = data_out_nibble[read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;
                            
							read_cnt = read_cnt + 1;							
							if ((ITCRCE && read_cnt == 4) || ~ITCRCE && (read_cnt == 2))
								 read_cnt = 0;	
                        end
                        else
                        begin
						    data_out[7:0]   = RDAR_reg;
							data_outb[7:0]  = ~RDAR_reg;
							if(read_cnt < 8)
							    DataDriveOut_SO = data_out[7-read_cnt];
							else if(read_cnt >= 8)
							    DataDriveOut_SO = data_outb[15-read_cnt];
							read_cnt = read_cnt + 1;
							if ((ITCRCE && read_cnt == 16) || ~ITCRCE && (read_cnt == 8))
								read_cnt = 0;		
                        end
                    end
                    else if (Instruct == RDCRC_4_0)
                    begin
                        if (Addr_idcfi <= 3)
                        begin
                            data_out[7:0] = ICRV[8*Addr_idcfi+7 -: 8];
                            if (QPI_IT)
                            begin
                                for (i=0;i<=5;i=i+1)
                                begin
                                    DataDriveOut_Dout[5-i] = data_out[7-i-read_cnt];
                                end
                                DataDriveOut_SO = data_out[1-read_cnt];
                                DataDriveOut_SI = data_out[0-read_cnt];

								if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;
                                
								read_cnt = read_cnt + 1;
                                if (read_cnt == 1)
                                begin
                                    read_cnt = 0;
                                    Addr_idcfi = Addr_idcfi + 1;
                                end
                            end
                        end
                    end
                    else if ((Instruct == RDAY2_C_0) && (~QPI_IT))
                    begin

                        rd_fast = 1'b1;
                        rd_slow = 1'b0;
                        dual    = 1'b0;
                        ddr     = 1'b0;

                        if (SectorSuspend != read_addr/(SecSize256+1))
                        begin												
							if (read_cnt == 0)
							begin
								if( ITCRCE && (crc_sgm_cnt != (sgm_size-1)))
								begin
								   //first_rd_byte = 0;
									ReturnSectorID(sect,read_addr);
									SecAddr = sect;
									READMEM(read_addr,SecAddr);	
									data_out = OutputD;
									GEN_CRC_RD8(data_out);
									//$display("read_addr= 0x%h, OutputD=0x%h, data_out=0x%h, sgm_cnt=%d",read_addr, OutputD, data_out, crc_sgm_cnt );
									crc_sgm_cnt = (crc_sgm_cnt+1)%(sgm_size+1);
									//->Mev1;
								end
								else if( ITCRCE && (crc_sgm_cnt == (sgm_size-1)))
								begin
									data_out_prev = ~crc_reg8_data;
									//$display("crc_reg8_data= 0x%h, data_out=0x%h, sgm_cnt=%d",crc_reg8_data, data_out, crc_sgm_cnt );
									crc_reg8_data = 8'hFF;
									crc_sgm_cnt = (crc_sgm_cnt+1)%(sgm_size+1);
									-> Mev2;
								end
							end				
							ReturnSectorID(sect,read_addr);
							SecAddr = sect;
							READMEM(read_addr,SecAddr);	
							
							if( ITCRCE && (crc_sgm_cnt == sgm_size))
								 data_out = data_out_prev;
							else
								data_out[7:0] = OutputD;
								
							//if (OutputD !== -1)
							if (data_out !== -1)  //Naim
							begin
								DataDriveOut_SO  = data_out[7-read_cnt];
							end
							else
							begin
								DataDriveOut_SO  = 8'bx;
							end
							read_cnt = read_cnt + 1;
							if (read_cnt == 8)
							begin
								read_cnt = 0;
								if(ITCRCE && (crc_sgm_cnt == sgm_size))
								begin
								   if (read_addr >= AddrRANGE)
										read_addr = 0;
								end
								else
								begin
									if (~CFR4V[4])  //Wrap Disabled
									begin
										if (read_addr == AddrRANGE)
											read_addr = 0;
										else
											read_addr = read_addr + 1;
									end
									else           //Wrap Enabled
									begin
										read_addr = read_addr + 1;

										if (read_addr % WrapLength == 0)
											read_addr = read_addr - WrapLength;
									end
								end
							end											
                        end
                        else
                        begin
                            DataDriveOut_SO  = 8'bxxxxxxxx;
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8)
                            begin
                                read_cnt = 0;

                                if (~CFR4V[4])  //Wrap Disabled
                                begin
                                    if (read_addr == AddrRANGE)
                                        read_addr = 0;
                                    else
                                        read_addr = read_addr + 1;
                                end
                                else           //Wrap Enabled
                                begin
                                    read_addr = read_addr + 1;

                                    if (read_addr % WrapLength == 0)
                                        read_addr = read_addr - WrapLength;
                                end
                            end
                        end
                    end
/*                     else if (Instruct == RDDYB_4_0 || Instruct == RDDYB_C_0)
                    begin
                    //Read DYB Access Register
                        ReturnSectorID(sect,Address);

                        if (DYB_bits[sect] == 1)
                            DYAV[7:0] = 8'hFF;
                        else
                        begin
                            DYAV[7:0] = 8'h0;
                        end

                        if (QPI_IT)
                        begin
                            DataDriveOut_Dout = DYAV[7:2];
                            DataDriveOut_SO   = DYAV[1];
                            DataDriveOut_SI   = DYAV[0];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;
                        end
                        else
                        begin
                            DataDriveOut_SO = DYAV[7-read_cnt];
                            read_cnt  = read_cnt + 1;
                            if (read_cnt == 8)
                                read_cnt = 0;
                        end
                    end */
										
					else if ((Instruct == RDDYB_4_0) || (Instruct == RDDYB_C_0))
                    begin
                        ReturnSectorID(sect,Address);

                        if (DYB_bits[sect] == 1)
                            DYAV[7:0] = 8'hFF;
                        else
                        begin
                            DYAV[7:0] = 8'h0;
                        end

						if (QPI_IT)
                        begin
                            data_out_nibble[0]  = DYAV[7:4];
							data_out_nibble[1]  = DYAV[3:0];
							data_out_nibble[2]  = ~DYAV[7:4];
							data_out_nibble[3]  = ~DYAV[3:0];
							{DataDriveOut_Dout[1:0], DataDriveOut_SO, DataDriveOut_SI} = data_out_nibble[read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;
                            
							read_cnt = read_cnt + 1;							
							if ((ITCRCE && read_cnt == 4) || ~ITCRCE && (read_cnt == 2))
								 read_cnt = 0;	
                        end
                        else
                        begin
						    data_out[7:0]   = DYAV;
							data_outb[7:0]  = ~DYAV;
							if(read_cnt < 8)
							    DataDriveOut_SO = data_out[7-read_cnt];
							else if(read_cnt >= 8)
							    DataDriveOut_SO = data_outb[15-read_cnt];
							read_cnt = read_cnt + 1;
							if ((ITCRCE && read_cnt == 16) || ~ITCRCE && (read_cnt == 8))
								read_cnt = 0;		
                        end
                    end
															
					else if (Instruct == RDPPB_4_0 || Instruct == RDPPB_C_0)
                    begin
                        ReturnSectorID(sect,Address);

                        if (PPB_bits[sect] == 1)
                            PPAV[7:0] = 8'hFF;
                        else
                        begin
                            PPAV[7:0] = 8'h0;
                        end

						if (QPI_IT)
                        begin
                            data_out_nibble[0]  = PPAV[7:4];
							data_out_nibble[1]  = PPAV[3:0];
							data_out_nibble[2]  = ~PPAV[7:4];
							data_out_nibble[3]  = ~PPAV[3:0];
							{DataDriveOut_Dout[1:0], DataDriveOut_SO, DataDriveOut_SI} = data_out_nibble[read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;
                            
							read_cnt = read_cnt + 1;							
							if ((ITCRCE && read_cnt == 4) || ~ITCRCE && (read_cnt == 2))
								 read_cnt = 0;	
                        end
                        else
                        begin
						    data_out[7:0]   = PPAV;
							data_outb[7:0]  = ~PPAV;
							if(read_cnt < 8)
							    DataDriveOut_SO = data_out[7-read_cnt];
							else if(read_cnt >= 8)
							    DataDriveOut_SO = data_outb[15-read_cnt];
							read_cnt = read_cnt + 1;
							if ((ITCRCE && read_cnt == 16) || ~ITCRCE && (read_cnt == 8))
								read_cnt = 0;		
                        end
                    end										
                end
                else if (oe_z)
                begin
                    if ((Instruct == RDAY1_C_0) || ((Instruct == RDAY1_4_0) && (~QPI_IT)))
                    begin
                        rd_fast = 1'b0;
                        rd_slow = 1'b1;
                        dual    = 1'b0;
                        ddr     = 1'b0;
                    end
                    else
                    begin
                        rd_fast = 1'b1;
                        rd_slow = 1'b0;
                        dual    = 1'b0;
                        ddr     = 1'b0;
                    end
                end
                if (falling_edge_write)
                begin
                    if (Instruct == RSEPD_0_0)
                    begin
                        STR2V[1] = 1'b0; // ERASES
                        STR1V[0] = 1'b1; // RDYBSY

                        Addr = SectorSuspend*(SecSize256+1);

                        ADDRHILO_SEC(AddrLo, AddrHi, Addr);
                        ERES = 1'b1;
                        ERES <= #5 1'b0;
                        RES_TO_SUSP_TIME = 1'b1;
                        RES_TO_SUSP_TIME <= #tdevice_RS 1'b0;//100us
                    end
                    else if ((Instruct==PRPGE_4_1 || Instruct==PRPGE_C_1 || Instruct==PRPG2_C_1 || Instruct==PRPG2_4_1 || Instruct==PRPG3_C_1 || Instruct==PRPG3_4_1)
							 && WRPGEN && ~PRGERR  && crc_pass_pgm && crc_pass_cmd)
                    begin
						$display("~~enanggo");
                        ReturnSectorID(sect,Address);

                        if (SectorSuspend != Address/(SecSize256+1))
                        begin
                            if (Sec_Prot[sect]== 0 && PPB_bits[sect]== 1 &&
                                DYB_bits[sect]== 1)
                            begin
                                PSTART = 1'b1;
                                PSTART <= #5 1'b0;
                                PGSUSP  = 0;
                                PGRES   = 0;
                                STR1V[0] = 1'b1;//RDYBSY
                                Addr     = Address;
                                Addr_tmp = Address;
                                wr_cnt   = Byte_number;
                                for (i=wr_cnt;i>=0;i=i-1)
                                begin
                                    if (Viol != 0)
                                        WData[i] = -1;
                                    else
                                        WData[i] = WByte[i];
                                end
                            end
                            else
                            begin
                                STR1V[0] = 1'b1;// RDYBSY
                                STR1V[6] = 1'b1;// PRGERR
                            end
                        end
                        else
                        begin
                            STR1V[0] = 1'b1;// RDYBSY
                            STR1V[6] = 1'b1;// PRGERR
                        end
                    end
                    else if ((Instruct == WRDYB_4_1 || Instruct == WRDYB_C_1) && WRPGEN)
                    begin
                        if (DYAV_in == 8'hFF || DYAV_in == 8'h00)
                        begin
                            ReturnSectorID(sect,Address);
                            PSTART   = 1'b1;
                            PSTART  <= #5 1'b0;
                            STR1V[0] = 1'b1;// RDYBSY
                        end
                        else
                        begin
                            STR1V[6] = 1'b1;// PRGERR
                            STR1V[0] = 1'b1;// RDYBSY
                        end
                    end
                    else if(((Instruct == WRENB_0_0) && crc_pass_cmd && ITCRCE) || ((Instruct == WRENB_0_0) && !ITCRCE ))
                        STR1V[1] = 1'b1; //WRPGEN
					else if(((Instruct == WRENV_0_0) && crc_pass_cmd && ITCRCE) || ((Instruct == WRENV_0_0) && !ITCRCE ))
						STR1V[1] = 1'b1; //WRPGEN
                    else if (Instruct == CLECC_0_0)
                    begin
                        ECSV[4] = 0;// 2 bits ECC detection
                        ECSV[3] = 0;// 1 bit ECC correction
                        INS0V[1] = 1;
                        INS0V[0] = 1;
                        ECTV = 16'h0000;
                        EATV = 32'h00000000;
                    end
                    else if (Instruct == CLPEF_0_0)
                    begin
                        STR1V[6] = 0;// PRGERR
                        STR1V[5] = 0;// ERSERR
                        STR1V[0] = 0;// RDYBSY
                    end

                    if (Instruct == SRSTE_0_0)
                    begin
                        RESET_EN = 1;
                    end
                    else
                    begin
                        RESET_EN <= 0;
                    end
                end
            end

            ERS_SUSP_PG:
            begin
                if (QPI_IT)
                begin
                    rd_fast = 1'b1;
                    rd_slow = 1'b0;
                    dual    = 1'b1;
                    ddr     = 1'b0;
                end
                else
                begin
                    rd_fast = 1'b1;
                    rd_slow = 1'b0;
                    dual    = 1'b0;
                    ddr     = 1'b0;
                end

                if (oe)
                begin
                    any_read = 1'b1;
                    if (Instruct == RDSR1_0_0)
                    begin
                    //Read Status Register 1
                       if (QPI_IT)
                        begin
							if(read_cnt == 0)
							  data_out[7:0] = STR1V;
							else 
							  data_out[7:0] = ~STR1V;
							for (i=0;i<=5;i=i+1)
							begin
								DataDriveOut_Dout[5-i] = data_out[7-i-read_cnt];
							end
							DataDriveOut_SO = data_out[1-read_cnt];
							DataDriveOut_SI = data_out[0-read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;
							
							read_cnt = read_cnt + 1;
							if (read_cnt == (1 + ITCRCE))
							begin
								read_cnt = 0;
							end							
                        end
                        else
                        begin
							DataDriveOut_SO = STR1Vbbar[15-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8 + 8*ITCRCE)
                                read_cnt = 0;
                        end
                    end
                    else if (Instruct == RDSR2_0_0)
                    begin
                        //Read Status Register 2
                        if (QPI_IT)
                        begin
                            data_out[7:0] = STR2V;
                            for (i=0;i<=5;i=i+1)
                            begin
                                DataDriveOut_Dout[5-i] = data_out[7-i-read_cnt];
                            end
                            DataDriveOut_SO = data_out[1-read_cnt];
                            DataDriveOut_SI = data_out[0-read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;

                            read_cnt = read_cnt + 1;
                            if (read_cnt == 1)
                            begin
                                read_cnt = 0;
                            end
                        end
                        else
                        begin
                            DataDriveOut_SO = STR2V[7-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8)
                                read_cnt = 0;
                        end
                    end
                    else if (Instruct == RDARG_C_0)
                    begin
                        READ_ALL_REG(read_addr, RDAR_reg);

                        if (QPI_IT)
                        begin
                            data_out_nibble[0]  = RDAR_reg[7:4];
							data_out_nibble[1]  = RDAR_reg[3:0];
							data_out_nibble[2]  = ~RDAR_reg[7:4];
							data_out_nibble[3]  = ~RDAR_reg[3:0];
							{DataDriveOut_Dout[1:0], DataDriveOut_SO, DataDriveOut_SI} = data_out_nibble[read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;
							
                            read_cnt = read_cnt + 1;							
							if ((ITCRCE && read_cnt == 4) || ~ITCRCE && (read_cnt == 2))
								 read_cnt = 0;	
                        end
                        else
                        begin
						    data_out[7:0]   = RDAR_reg;
							data_outb[7:0]  = ~RDAR_reg;
							if(read_cnt < 8)
							    DataDriveOut_SO = data_out[7-read_cnt];
							else if(read_cnt >= 8)
							    DataDriveOut_SO = data_outb[15-read_cnt];
							read_cnt = read_cnt + 1;
							if ((ITCRCE && read_cnt == 16) || ~ITCRCE && (read_cnt == 8))
								read_cnt = 0;		
                        end
                    end
                end

                if(current_state_event && current_state == ERS_SUSP_PG)
                begin
                    if (~PDONE)
                    begin
                        ADDRHILO_PG(AddrLo, AddrHi, Addr);
                        cnt = 0;
                        for (i=0;i<=wr_cnt;i=i+1)
                        begin
                            new_int = WData[i];
                            ReturnSectorID(sect,read_addr);
                            memory_features_i0.read_mem_w(
                                mem_data,
                                Addr + i - cnt
                                );
                            if (corrupt_Sec[sect])
                            begin
                                if (mem_data== MaxData+1)
                                    mem_data = MaxData;
                                else if (mem_data == MaxData)
                                    mem_data = -1;
                            end
                            old_int = mem_data;
                            if (new_int > -1)
                            begin
                                new_bit = new_int;
                                if (old_int > -1)
                                begin
                                    old_bit = old_int;
                                    for(j=0;j<=7;j=j+1)
                                    begin
                                        if (~old_bit[j])
                                            new_bit[j] = 1'b0;
                                    end
                                    new_int = new_bit;
                                end
                                WData[i] = new_int;
                            end
                            else
                            begin
                                WData[i] = -1;
                            end

                            if ((Addr + i) == AddrHi)
                            begin
                                Addr = AddrLo;
                                cnt = i + 1;
                            end
                        end
                    end
                    cnt =0;
                end

                if (PDONE)
                begin
                    if (((CFR4V[3] == 1'b1)  || (non_industrial_temp == 1'b1)) 
                          && (ECC_ERR > 0) )
                    begin
                        STR1V[0] = 1'b1; //RDYBSY
                        STR1V[1] = 1'b1; //WRPGEN
                        STR1V[6] = 1'b1; //PRGERR
                        ECC_ERR = 0;
                        $display ("WARNING: For non-industrial temperatures ");
                        $display ("it is not allowed to have multi-programming ");
                        $display ("without erasing previously the sector!");
                        $display ("multi-pass programming within the same sector will result in a Program Error.");
                    end
                    else
                    begin
                        STR1V[0] = 1'b0; //RDYBSY
                        STR1V[1] = 1'b0; //WRPGEN
                        ECC_ERR = 0;
                    end

                    for (i=0;i<=wr_cnt;i=i+1)
                    begin
                        memory_features_i0.write_mem_w(
                                Addr_tmp + i -cnt,
                                WData[i]
                                    );
                        if ((Addr_tmp + i) == AddrHi)
                        begin
                            Addr_tmp = AddrLo;
                            cnt = i + 1;
                        end
                    end
                end

                if (falling_edge_write)
                begin
                    if ((Instruct == SPEPD_0_0) && ~PRGSUSP_in)
                    begin
                        if (~RES_TO_SUSP_TIME)
                        begin
                            PGSUSP = 1'b1;
                            PGSUSP <= #5 1'b0;
                            PRGSUSP_in = 1'b1;
                        end
                        else
                        begin
                            $display("Minimum for tRS is not satisfied! ",
                                     "PGSP command is ignored");
                        end
                    end
                end
            end

            ERS_SUSP_PG_SUSP:
            begin
                if (QPI_IT)
                begin
                    rd_fast = 1'b1;
                    rd_slow = 1'b0;
                    dual    = 1'b1;
                    ddr     = 1'b0;
                end
                else
                begin
                    rd_fast = 1'b1;
                    rd_slow = 1'b0;
                    dual    = 1'b0;
                    ddr     = 1'b0;
                end

                if (PRGSUSP_out && PRGSUSP_in)
                begin
                    PRGSUSP_in = 1'b0;
                    //The RDYBSY bit in the Status Register will indicate that
                    //the device is ready for another operation.
                    STR1V[0] = 1'b0;
                    //The Program Suspend (PROGMS) bit in the Status Register will
                    //be set to the logical “1” state to indicate that the
                    //program operation has been suspended.
                    STR2V[0] = 1'b1;
                end

                if (oe)
                begin
                    any_read = 1'b1;
                    if (Instruct == RDSR1_0_0)
                    begin
                    //Read Status Register 1
                       if (QPI_IT)
                        begin
							if(read_cnt == 0)
							  data_out[7:0] = STR1V;
							else 
							  data_out[7:0] = ~STR1V;
							for (i=0;i<=5;i=i+1)
							begin
								DataDriveOut_Dout[5-i] = data_out[7-i-read_cnt];
							end
							DataDriveOut_SO = data_out[1-read_cnt];
							DataDriveOut_SI = data_out[0-read_cnt];
							
							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;
							
							read_cnt = read_cnt + 1;
							if (read_cnt == (1 + ITCRCE))
							begin
								read_cnt = 0;
							end							
                        end
                        else
                        begin
							DataDriveOut_SO = STR1Vbbar[15-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8 + 8*ITCRCE)
                                read_cnt = 0;
                        end
                    end
                    else if (Instruct == RDSR2_0_0)
                    begin
                        //Read Status Register 2
                        if (QPI_IT)
                        begin
                            data_out[7:0] = STR2V;
                            for (i=0;i<=5;i=i+1)
                            begin
                                DataDriveOut_Dout[5-i] = data_out[7-i-read_cnt];
                            end
                            DataDriveOut_SO = data_out[1-read_cnt];
                            DataDriveOut_SI = data_out[0-read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;

                            read_cnt = read_cnt + 1;
                            if (read_cnt == 1)
                            begin
                                read_cnt = 0;
                            end
                        end
                        else
                        begin
                            DataDriveOut_SO = STR2V[7-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8)
                                read_cnt = 0;
                        end
                    end
                    else if (Instruct == RDARG_C_0)
                    begin
                        READ_ALL_REG(read_addr, RDAR_reg);

                        if (QPI_IT)
                        begin
                            data_out_nibble[0]  = RDAR_reg[7:4];
							data_out_nibble[1]  = RDAR_reg[3:0];
							data_out_nibble[2]  = ~RDAR_reg[7:4];
							data_out_nibble[3]  = ~RDAR_reg[3:0];
							{DataDriveOut_Dout[1:0], DataDriveOut_SO, DataDriveOut_SI} = data_out_nibble[read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;

                            read_cnt = read_cnt + 1;							
							if ((ITCRCE && read_cnt == 4) || ~ITCRCE && (read_cnt == 2))
								 read_cnt = 0;	
                        end
                        else
                        begin
						    data_out[7:0]   = RDAR_reg;
							data_outb[7:0]  = ~RDAR_reg;
							if(read_cnt < 8)
							    DataDriveOut_SO = data_out[7-read_cnt];
							else if(read_cnt >= 8)
							    DataDriveOut_SO = data_outb[15-read_cnt];
							read_cnt = read_cnt + 1;
							if ((ITCRCE && read_cnt == 16) || ~ITCRCE && (read_cnt == 8))
								read_cnt = 0;		
                        end
                    end
                    else if (Instruct == RDCRC_4_0)
                    begin
                        if (Addr_idcfi <= 3)
                        begin
                            data_out[7:0] = ICRV[8*Addr_idcfi+7 -: 8];
                            if (QPI_IT)
                            begin
                                for (i=0;i<=5;i=i+1)
                                begin
                                    DataDriveOut_Dout[5-i] = data_out[7-i-read_cnt];
                                end
                                DataDriveOut_SO = data_out[1-read_cnt];
                                DataDriveOut_SI = data_out[0-read_cnt];

								if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;
                                
								read_cnt = read_cnt + 1;
                                if (read_cnt == 1)
                                begin
                                    read_cnt = 0;
                                    Addr_idcfi = Addr_idcfi + 1;
                                end
                            end
                        end
                    end
                    else if ((Instruct == RDAY2_C_0) && (~QPI_IT))
                    begin
                        if (SectorSuspend != read_addr/(SecSize256+1) &&
                            pgm_page != read_addr / (PageSize+1))
                        begin
							if (read_cnt == 0)
							begin
								if( ITCRCE && (crc_sgm_cnt != (sgm_size-1)))
								begin
								   //first_rd_byte = 0;
									ReturnSectorID(sect,read_addr);
									SecAddr = sect;
									READMEM(read_addr,SecAddr);	
									data_out = OutputD;
									GEN_CRC_RD8(data_out);
									//$display("read_addr= 0x%h, OutputD=0x%h, data_out=0x%h, sgm_cnt=%d",read_addr, OutputD, data_out, crc_sgm_cnt );
									crc_sgm_cnt = (crc_sgm_cnt+1)%(sgm_size+1);
									//->Mev1;
								end
								else if( ITCRCE && (crc_sgm_cnt == (sgm_size-1)))
								begin
									data_out_prev = ~crc_reg8_data;
									//$display("crc_reg8_data= 0x%h, data_out=0x%h, sgm_cnt=%d",crc_reg8_data, data_out, crc_sgm_cnt );
									crc_reg8_data = 8'hFF;
									crc_sgm_cnt = (crc_sgm_cnt+1)%(sgm_size+1);
									-> Mev2;
								end
							end				
							ReturnSectorID(sect,read_addr);
							SecAddr = sect;
							READMEM(read_addr,SecAddr);	
							
							if( ITCRCE && (crc_sgm_cnt == sgm_size))
								 data_out = data_out_prev;
							else
								data_out[7:0] = OutputD;
								
							//if (OutputD !== -1)
							if (data_out !== -1)  //Naim
							begin
								DataDriveOut_SO  = data_out[7-read_cnt];
							end
							else
							begin
								DataDriveOut_SO  = 8'bx;
							end
							read_cnt = read_cnt + 1;
							if (read_cnt == 8)
							begin
								read_cnt = 0;
								if(ITCRCE && (crc_sgm_cnt == sgm_size))
								begin
								   if (read_addr >= AddrRANGE)
										read_addr = 0;
								end
								else if(ITCRCE && (crc_sgm_cnt != sgm_size))
								begin
								   if (read_addr >= AddrRANGE)
										read_addr = 0;
									else
										read_addr = read_addr + 1;
								end
								else
								begin
									if (read_addr >= AddrRANGE)
										read_addr = 0;
									else
										read_addr = read_addr + 1;
								end
							end							
                        end
                        else
                        begin
                            DataDriveOut_SO  = 8'bxxxxxxxx;
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8)
                            begin
                                read_cnt = 0;

                                if (~CFR4V[4])  //Wrap Disabled
                                begin
                                    if (read_addr == AddrRANGE)
                                        read_addr = 0;
                                    else
                                        read_addr = read_addr + 1;
                                end
                                else           //Wrap Enabled
                                begin
                                    read_addr = read_addr + 1;

                                    if (read_addr % WrapLength == 0)
                                        read_addr = read_addr - WrapLength;
                                end
                            end
                        end
                    end
                end
                else if (oe_z)
                begin
                    if ((Instruct == RDAY1_C_0) || ((Instruct == RDAY1_4_0) && (~QPI_IT)))
                    begin
                        rd_fast = 1'b0;
                        rd_slow = 1'b1;
                        dual    = 1'b0;
                        ddr     = 1'b0;
                    end
                    else
                    begin
                        rd_fast = 1'b1;
                        rd_slow = 1'b0;
                        dual    = 1'b0;
                        ddr     = 1'b0;
                    end
                end

                if (falling_edge_write)
                begin
                    if (Instruct == RSEPD_0_0)
                    begin
                        STR2V[0] = 1'b0; // PROGMS
                        STR1V[0] = 1'b1; // RDYBSY
                        PGRES  = 1'b1;
                        PGRES <= #5 1'b0;
                        RES_TO_SUSP_TIME = 1'b1;
                        RES_TO_SUSP_TIME <= #tdevice_RS 1'b0;//100us
                    end
                    else if (Instruct == CLECC_0_0)
                    begin
                        ECSV[4] = 0;// 2 bits ECC detection
                        ECSV[3] = 0;// 1 bit ECC correction
                        INS0V[1] = 1;
                        INS0V[0] = 1;
                        ECTV = 16'h0000;
                        EATV = 32'h00000000;
                    end
                    else if (Instruct == CLPEF_0_0)
                    begin
                        STR1V[6] = 0;// PRGERR
                        STR1V[5] = 0;// ERSERR
                        STR1V[0] = 0;// RDYBSY
                    end

                    if (Instruct == SRSTE_0_0)
                    begin
                        RESET_EN = 1;
                    end
                    else
                    begin
                        RESET_EN <= 0;
                    end
                end
            end

            PASS_PG:
            begin
                rd_fast = 1'b1;
                rd_slow = 1'b0;
                dual    = 1'b0;
                ddr     = 1'b0;

                if (oe)
                begin
                    any_read = 1'b1;
                    if (Instruct == RDSR1_0_0)
                    begin
                    //Read Status Register 1
                       if (QPI_IT)
                        begin
							if(read_cnt == 0)
							  data_out[7:0] = STR1V;
							else 
							  data_out[7:0] = ~STR1V;
							for (i=0;i<=5;i=i+1)
							begin
								DataDriveOut_Dout[5-i] = data_out[7-i-read_cnt];
							end
							DataDriveOut_SO = data_out[1-read_cnt];
							DataDriveOut_SI = data_out[0-read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;
							
							read_cnt = read_cnt + 1;
							if (read_cnt == (1 + ITCRCE))
							begin
								read_cnt = 0;
							end							
                        end
                        else
                        begin
							DataDriveOut_SO = STR1Vbbar[15-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8 + 8*ITCRCE)
                                read_cnt = 0;
                        end
                    end
                    else if (Instruct == RDSR2_0_0)
                    begin
                        //Read Status Register 2
                        if (QPI_IT)
                        begin
                            data_out[7:0] = STR2V;
                            for (i=0;i<=5;i=i+1)
                            begin
                                DataDriveOut_Dout[5-i] = data_out[7-i-read_cnt];
                            end
                            DataDriveOut_SO = data_out[1-read_cnt];
                            DataDriveOut_SI = data_out[0-read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;

                            read_cnt = read_cnt + 1;
                            if (read_cnt == 1)
                            begin
                                read_cnt = 0;
                            end
                        end
                        else
                        begin
                            DataDriveOut_SO = STR2V[7-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8)
                                read_cnt = 0;
                        end
                    end
                    else if (Instruct == RDARG_C_0)
                    begin
                        READ_ALL_REG(read_addr, RDAR_reg);

                        if (QPI_IT)
                        begin
                            data_out_nibble[0]  = RDAR_reg[7:4];
							data_out_nibble[1]  = RDAR_reg[3:0];
							data_out_nibble[2]  = ~RDAR_reg[7:4];
							data_out_nibble[3]  = ~RDAR_reg[3:0];
							{DataDriveOut_Dout[1:0], DataDriveOut_SO, DataDriveOut_SI} = data_out_nibble[read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;

                            read_cnt = read_cnt + 1;							
							if ((ITCRCE && read_cnt == 4) || ~ITCRCE && (read_cnt == 2))
								 read_cnt = 0;	
                        end
                        else
                        begin
						    data_out[7:0]   = RDAR_reg;
							data_outb[7:0]  = ~RDAR_reg;
							if(read_cnt < 8)
							    DataDriveOut_SO = data_out[7-read_cnt];
							else if(read_cnt >= 8)
							    DataDriveOut_SO = data_outb[15-read_cnt];
							read_cnt = read_cnt + 1;
							if ((ITCRCE && read_cnt == 16) || ~ITCRCE && (read_cnt == 8))
								read_cnt = 0;		
                        end
                    end
                end

                new_pass = PWDO_in;
                old_pass = PWDO;
                for (i=0;i<=63;i=i+1)
                begin
                    if (old_pass[j] == 0)
                        new_pass[j] = 0;
                end

                if (PDONE)
                begin
                    PWDO = new_pass;
                    STR1V[0] = 1'b0; //RDYBSY
                    STR1V[1] = 1'b0; //WRPGEN
                end
            end

            PASS_UNLOCK:
            begin
                rd_fast = 1'b1;
                rd_slow = 1'b0;
                dual    = 1'b0;
                ddr     = 1'b0;

                if (oe)
                begin
                    any_read = 1'b1;
                    if (Instruct == RDSR1_0_0)
                    begin
                    //Read Status Register 1
                       if (QPI_IT)
                        begin
							if(read_cnt == 0)
							  data_out[7:0] = STR1V;
							else 
							  data_out[7:0] = ~STR1V;
							for (i=0;i<=5;i=i+1)
							begin
								DataDriveOut_Dout[5-i] = data_out[7-i-read_cnt];
							end
							DataDriveOut_SO = data_out[1-read_cnt];
							DataDriveOut_SI = data_out[0-read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;
							
							read_cnt = read_cnt + 1;
							if (read_cnt == (1 + ITCRCE))
							begin
								read_cnt = 0;
							end							
                        end
                        else
                        begin
							DataDriveOut_SO = STR1Vbbar[15-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8 + 8*ITCRCE)
                                read_cnt = 0;
                        end
                    end
                    else if (Instruct == RDSR2_0_0)
                    begin
                        //Read Status Register 2
                        if (QPI_IT)
                        begin
                            data_out[7:0] = STR2V;
                            for (i=0;i<=5;i=i+1)
                            begin
                                DataDriveOut_Dout[5-i] = data_out[7-i-read_cnt];
                            end
                            DataDriveOut_SO = data_out[1-read_cnt];
                            DataDriveOut_SI = data_out[0-read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;

                            read_cnt = read_cnt + 1;
                            if (read_cnt == 1)
                            begin
                                read_cnt = 0;
                            end
                        end
                        else
                        begin
                            DataDriveOut_SO = STR2V[7-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8)
                                read_cnt = 0;
                        end
                    end
                    else if (Instruct == RDARG_C_0)
                    begin
                        READ_ALL_REG(read_addr, RDAR_reg);

                        if (QPI_IT)
                        begin 
                            data_out_nibble[0]  = RDAR_reg[7:4];
							data_out_nibble[1]  = RDAR_reg[3:0];
							data_out_nibble[2]  = ~RDAR_reg[7:4];
							data_out_nibble[3]  = ~RDAR_reg[3:0];
							{DataDriveOut_Dout[1:0], DataDriveOut_SO, DataDriveOut_SI} = data_out_nibble[read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;
                            
							read_cnt = read_cnt + 1;							
							if ((ITCRCE && read_cnt == 4) || ~ITCRCE && (read_cnt == 2))
								 read_cnt = 0;	
                        end
                        else
                        begin
						    data_out[7:0]   = RDAR_reg;
							data_outb[7:0]  = ~RDAR_reg;
							if(read_cnt < 8)
							    DataDriveOut_SO = data_out[7-read_cnt];
							else if(read_cnt >= 8)
							    DataDriveOut_SO = data_outb[15-read_cnt];
							read_cnt = read_cnt + 1;
							if ((ITCRCE && read_cnt == 16) || ~ITCRCE && (read_cnt == 8))
								read_cnt = 0;		
                        end
                    end
                end

                if (PASS_TEMP == PWDO)
                begin
                    PASS_UNLOCKED = 1'b1;
                end
                else
                begin
                    PASS_UNLOCKED = 1'b0;
                end
                if (PASSULCK_out)
                begin
                    if ((PASS_UNLOCKED == 1'b1) && (~ASPPWD))
                    begin
                        PPLV [0] = 1'b1;
                        STR1V[0] = 1'b0; //RDYBSY
                    end
                    else
                    begin
                        STR1V[6] = 1'b1; //PRGERR
                        STR1V[0] = 1'b1; //RDYBSY
                        $display ("Incorrect Password");
                        PASSACC_in = 1'b1;
                    end
                    PASSULCK_in = 1'b0;
                end
            end

            PPB_PG:
            begin
                rd_fast = 1'b1;
                rd_slow = 1'b0;
                dual    = 1'b0;
                ddr     = 1'b0;

                if (oe)
                begin
                    any_read = 1'b1;
                    if (Instruct == RDSR1_0_0)
                    begin
                    //Read Status Register 1
                       if (QPI_IT)
                        begin
							if(read_cnt == 0)
							  data_out[7:0] = STR1V;
							else 
							  data_out[7:0] = ~STR1V;
							for (i=0;i<=5;i=i+1)
							begin
								DataDriveOut_Dout[5-i] = data_out[7-i-read_cnt];
							end
							DataDriveOut_SO = data_out[1-read_cnt];
							DataDriveOut_SI = data_out[0-read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;
							
							read_cnt = read_cnt + 1;
							if (read_cnt == (1 + ITCRCE))
							begin
								read_cnt = 0;
							end							
                        end
                        else
                        begin
							DataDriveOut_SO = STR1Vbbar[15-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8 + 8*ITCRCE)
                                read_cnt = 0;
                        end
                    end
                    else if (Instruct == RDSR2_0_0)
                    begin
                        //Read Status Register 2
                        if (QPI_IT)
                        begin
                            data_out[7:0] = STR2V;
                            for (i=0;i<=5;i=i+1)
                            begin
                                DataDriveOut_Dout[5-i] = data_out[7-i-read_cnt];
                            end
                            DataDriveOut_SO = data_out[1-read_cnt];
                            DataDriveOut_SI = data_out[0-read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;

                            read_cnt = read_cnt + 1;
                            if (read_cnt == 1)
                            begin
                                read_cnt = 0;
                            end
                        end
                        else
                        begin
                            DataDriveOut_SO = STR2V[7-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8)
                                read_cnt = 0;
                        end
                    end
                    else if (Instruct == RDARG_C_0)
                    begin
                        READ_ALL_REG(read_addr, RDAR_reg);

                        if (QPI_IT)
                        begin
                            data_out_nibble[0]  = RDAR_reg[7:4];
							data_out_nibble[1]  = RDAR_reg[3:0];
							data_out_nibble[2]  = ~RDAR_reg[7:4];
							data_out_nibble[3]  = ~RDAR_reg[3:0];
							{DataDriveOut_Dout[1:0], DataDriveOut_SO, DataDriveOut_SI} = data_out_nibble[read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;
                            
							read_cnt = read_cnt + 1;							
							if ((ITCRCE && read_cnt == 4) || ~ITCRCE && (read_cnt == 2))
								 read_cnt = 0;	
                        end
                        else
                        begin
						    data_out[7:0]   = RDAR_reg;
							data_outb[7:0]  = ~RDAR_reg;
							if(read_cnt < 8)
							    DataDriveOut_SO = data_out[7-read_cnt];
							else if(read_cnt >= 8)
							    DataDriveOut_SO = data_outb[15-read_cnt];
							read_cnt = read_cnt + 1;
							if ((ITCRCE && read_cnt == 16) || ~ITCRCE && (read_cnt == 8))
								read_cnt = 0;		
                        end
                    end
                end

                if (PDONE)
                begin
                    PPB_bits[sect]= 1'b0;
                    STR1V[0] = 1'b0;
                    STR1V[1] = 1'b0;
                end
            end

            PPB_ERS:
            begin
                rd_fast = 1'b1;
                rd_slow = 1'b0;
                dual    = 1'b0;
                ddr     = 1'b0;

                if (oe)
                begin
                    any_read = 1'b1;
                    if (Instruct == RDSR1_0_0)
                    begin
                    //Read Status Register 1
                       if (QPI_IT)
                        begin
							if(read_cnt == 0)
							  data_out[7:0] = STR1V;
							else 
							  data_out[7:0] = ~STR1V;
							for (i=0;i<=5;i=i+1)
							begin
								DataDriveOut_Dout[5-i] = data_out[7-i-read_cnt];
							end
							DataDriveOut_SO = data_out[1-read_cnt];
							DataDriveOut_SI = data_out[0-read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;
							
							read_cnt = read_cnt + 1;
							if (read_cnt == (1 + ITCRCE))
							begin
								read_cnt = 0;
							end							
                        end
                        else
                        begin
							DataDriveOut_SO = STR1Vbbar[15-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8 + 8*ITCRCE)
                                read_cnt = 0;
                        end
                    end
                    else if (Instruct == RDSR2_0_0)
                    begin
                        //Read Status Register 2
                        if (QPI_IT)
                        begin
                            data_out[7:0] = STR2V;
                            for (i=0;i<=5;i=i+1)
                            begin
                                DataDriveOut_Dout[5-i] = data_out[7-i-read_cnt];
                            end
                            DataDriveOut_SO = data_out[1-read_cnt];
                            DataDriveOut_SI = data_out[0-read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;

                            read_cnt = read_cnt + 1;
                            if (read_cnt == 1)
                            begin
                                read_cnt = 0;
                            end
                        end
                        else
                        begin
                            DataDriveOut_SO = STR2V[7-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8)
                                read_cnt = 0;
                        end
                    end
                    else if (Instruct == RDARG_C_0)
                    begin
                        READ_ALL_REG(read_addr, RDAR_reg);

                        if (QPI_IT)
                        begin
                            data_out_nibble[0]  = RDAR_reg[7:4];
							data_out_nibble[1]  = RDAR_reg[3:0];
							data_out_nibble[2]  = ~RDAR_reg[7:4];
							data_out_nibble[3]  = ~RDAR_reg[3:0];
							{DataDriveOut_Dout[1:0], DataDriveOut_SO, DataDriveOut_SI} = data_out_nibble[read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;
                            
							read_cnt = read_cnt + 1;							
							if ((ITCRCE && read_cnt == 4) || ~ITCRCE && (read_cnt == 2))
								 read_cnt = 0;	
                        end
                        else
                        begin
						    data_out[7:0]   = RDAR_reg;
							data_outb[7:0]  = ~RDAR_reg;
							if(read_cnt < 8)
							    DataDriveOut_SO = data_out[7-read_cnt];
							else if(read_cnt >= 8)
							    DataDriveOut_SO = data_outb[15-read_cnt];
							read_cnt = read_cnt + 1;
							if ((ITCRCE && read_cnt == 16) || ~ITCRCE && (read_cnt == 8))
								read_cnt = 0;		
                        end
                    end
                end

                if (PPBERASE_out)
                begin

                    PPB_bits = {8192{1'b1}};

                    STR1V[0] = 1'b0;
                    STR1V[1] = 1'b0;
                    PPBERASE_in = 1'b0;
                end
            end

            PLB_PG:
            begin
                rd_fast = 1'b1;
                rd_slow = 1'b0;
                dual    = 1'b0;
                ddr     = 1'b0;

                if (oe)
                begin
                    any_read = 1'b1;
                    if (Instruct == RDSR1_0_0)
                    begin
                    //Read Status Register 1
                       if (QPI_IT)
                        begin
							if(read_cnt == 0)
							  data_out[7:0] = STR1V;
							else 
							  data_out[7:0] = ~STR1V;
							for (i=0;i<=5;i=i+1)
							begin
								DataDriveOut_Dout[5-i] = data_out[7-i-read_cnt];
							end
							DataDriveOut_SO = data_out[1-read_cnt];
							DataDriveOut_SI = data_out[0-read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;
							
							read_cnt = read_cnt + 1;
							if (read_cnt == (1 + ITCRCE))
							begin
								read_cnt = 0;
							end							
                        end
                        else
                        begin
							DataDriveOut_SO = STR1Vbbar[15-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8 + 8*ITCRCE)
                                read_cnt = 0;
                        end
                    end
                    else if (Instruct == RDSR2_0_0)
                    begin
                        //Read Status Register 2
                        if (QPI_IT)
                        begin
                            data_out[7:0] = STR2V;
                            for (i=0;i<=5;i=i+1)
                            begin
                                DataDriveOut_Dout[5-i] = data_out[7-i-read_cnt];
                            end
                            DataDriveOut_SO = data_out[1-read_cnt];
                            DataDriveOut_SI = data_out[0-read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;

                            read_cnt = read_cnt + 1;
                            if (read_cnt == 1)
                            begin
                                read_cnt = 0;
                            end
                        end
                        else
                        begin
                            DataDriveOut_SO = STR2V[7-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8)
                                read_cnt = 0;
                        end
                    end
                    else if (Instruct == RDARG_C_0)
                    begin
                        READ_ALL_REG(read_addr, RDAR_reg);

                        if (QPI_IT)
                        begin
                            data_out_nibble[0]  = RDAR_reg[7:4];
							data_out_nibble[1]  = RDAR_reg[3:0];
							data_out_nibble[2]  = ~RDAR_reg[7:4];
							data_out_nibble[3]  = ~RDAR_reg[3:0];
							{DataDriveOut_Dout[1:0], DataDriveOut_SO, DataDriveOut_SI} = data_out_nibble[read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;
                            
							read_cnt = read_cnt + 1;							
							if ((ITCRCE && read_cnt == 4) || ~ITCRCE && (read_cnt == 2))
								 read_cnt = 0;	
                        end
                        else
                        begin
						    data_out[7:0]   = RDAR_reg;
							data_outb[7:0]  = ~RDAR_reg;
							if(read_cnt < 8)
							    DataDriveOut_SO = data_out[7-read_cnt];
							else if(read_cnt >= 8)
							    DataDriveOut_SO = data_outb[15-read_cnt];
							read_cnt = read_cnt + 1;
							if ((ITCRCE && read_cnt == 16) || ~ITCRCE && (read_cnt == 8))
								read_cnt = 0;		
                        end
                    end
                end

                if (PDONE)
                begin
                    PPLV[0] = 1'b0;
                    STR1V[0] = 1'b0; //RDYBSY
                    STR1V[1] = 1'b0; //WRPGEN
                end
            end

            DYB_PG:
            begin
                if (QPI_IT)
                begin
                    rd_fast = 1'b1;
                    rd_slow = 1'b0;
                    dual    = 1'b1;
                    ddr     = 1'b0;
                end
                else
                begin
                    rd_fast = 1'b1;
                    rd_slow = 1'b0;
                    dual    = 1'b0;
                    ddr     = 1'b0;
                end

                if (oe)
                begin
                    any_read = 1'b1;
                    if (Instruct == RDSR1_0_0)
                    begin
                    //Read Status Register 1
                       if (QPI_IT)
                        begin
							if(read_cnt == 0)
							  data_out[7:0] = STR1V;
							else 
							  data_out[7:0] = ~STR1V;
							for (i=0;i<=5;i=i+1)
							begin
								DataDriveOut_Dout[5-i] = data_out[7-i-read_cnt];
							end
							DataDriveOut_SO = data_out[1-read_cnt];
							DataDriveOut_SI = data_out[0-read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;
							
							read_cnt = read_cnt + 1;
							if (read_cnt == (1 + ITCRCE))
							begin
								read_cnt = 0;
							end							
                        end
                        else
                        begin
							DataDriveOut_SO = STR1Vbbar[15-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8 + 8*ITCRCE)
                                read_cnt = 0;
                        end
                    end
                    else if (Instruct == RDSR2_0_0)
                    begin
                        //Read Status Register 2
                        if (QPI_IT)
                        begin
                            data_out[7:0] = STR2V;
                            for (i=0;i<=5;i=i+1)
                            begin
                                DataDriveOut_Dout[5-i] = data_out[7-i-read_cnt];
                            end
                            DataDriveOut_SO = data_out[1-read_cnt];
                            DataDriveOut_SI = data_out[0-read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;

                            read_cnt = read_cnt + 1;
                            if (read_cnt == 1)
                            begin
                                read_cnt = 0;
                            end
                        end
                        else
                        begin
                            DataDriveOut_SO = STR2V[7-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8)
                                read_cnt = 0;
                        end
                    end
                    else if (Instruct == RDARG_C_0)
                    begin
                        READ_ALL_REG(read_addr, RDAR_reg);

                        if (QPI_IT)
                        begin
                            data_out_nibble[0]  = RDAR_reg[7:4];
							data_out_nibble[1]  = RDAR_reg[3:0];
							data_out_nibble[2]  = ~RDAR_reg[7:4];
							data_out_nibble[3]  = ~RDAR_reg[3:0];
							{DataDriveOut_Dout[1:0], DataDriveOut_SO, DataDriveOut_SI} = data_out_nibble[read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;

                            read_cnt = read_cnt + 1;							
							if ((ITCRCE && read_cnt == 4) || ~ITCRCE && (read_cnt == 2))
								 read_cnt = 0;	
                        end
                        else
                        begin
						    data_out[7:0]   = RDAR_reg;
							data_outb[7:0]  = ~RDAR_reg;
							if(read_cnt < 8)
							    DataDriveOut_SO = data_out[7-read_cnt];
							else if(read_cnt >= 8)
							    DataDriveOut_SO = data_outb[15-read_cnt];
							read_cnt = read_cnt + 1;
							if ((ITCRCE && read_cnt == 16) || ~ITCRCE && (read_cnt == 8))
								read_cnt = 0;		
                        end
                    end
                end

                if (PDONE)
                begin
                    DYAV = DYAV_in;
                    if (DYAV == 8'hFF)
                    begin
                        DYB_bits[sect]= 1'b1;
                    end
                    else if (DYAV == 8'h00)
                    begin
                        DYB_bits[sect]= 1'b0;
                    end

                    STR1V[0] = 1'b0;
                    STR1V[1] = 1'b0;
                end
            end

            ASP_PG:
            begin
                rd_fast = 1'b1;
                rd_slow = 1'b0;
                dual    = 1'b0;
                ddr     = 1'b0;

                if (oe)
                begin
                    any_read = 1'b1;
                    if (Instruct == RDSR1_0_0)
                    begin
                    //Read Status Register 1
                       if (QPI_IT)
                        begin
							if(read_cnt == 0)
							  data_out[7:0] = STR1V;
							else 
							  data_out[7:0] = ~STR1V;
							for (i=0;i<=5;i=i+1)
							begin
								DataDriveOut_Dout[5-i] = data_out[7-i-read_cnt];
							end
							DataDriveOut_SO = data_out[1-read_cnt];
							DataDriveOut_SI = data_out[0-read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;
							
							read_cnt = read_cnt + 1;
							if (read_cnt == (1 + ITCRCE))
							begin
								read_cnt = 0;
							end							
                        end
                        else
                        begin
							DataDriveOut_SO = STR1Vbbar[15-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8 + 8*ITCRCE)
                                read_cnt = 0;
                        end
                    end
                    else if (Instruct == RDSR2_0_0)
                    begin
                        //Read Status Register 2
                        if (QPI_IT)
                        begin
                            data_out[7:0] = STR2V;
                            for (i=0;i<=5;i=i+1)
                            begin
                                DataDriveOut_Dout[5-i] = data_out[7-i-read_cnt];
                            end
                            DataDriveOut_SO = data_out[1-read_cnt];
                            DataDriveOut_SI = data_out[0-read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;

                            read_cnt = read_cnt + 1;
                            if (read_cnt == 1)
                            begin
                                read_cnt = 0;
                            end
                        end
                        else
                        begin
                            DataDriveOut_SO = STR2V[7-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8)
                                read_cnt = 0;
                        end
                    end
                    else if (Instruct == RDARG_C_0)
                    begin
                        READ_ALL_REG(read_addr, RDAR_reg);

                        if (QPI_IT)
                        begin
                            data_out_nibble[0]  = RDAR_reg[7:4];
							data_out_nibble[1]  = RDAR_reg[3:0];
							data_out_nibble[2]  = ~RDAR_reg[7:4];
							data_out_nibble[3]  = ~RDAR_reg[3:0];
							{DataDriveOut_Dout[1:0], DataDriveOut_SO, DataDriveOut_SI} = data_out_nibble[read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;
                            
							read_cnt = read_cnt + 1;							
							if ((ITCRCE && read_cnt == 4) || ~ITCRCE && (read_cnt == 2))
								 read_cnt = 0;	
                        end
                        else
                        begin
						    data_out[7:0]   = RDAR_reg;
							data_outb[7:0]  = ~RDAR_reg;
							if(read_cnt < 8)
							    DataDriveOut_SO = data_out[7-read_cnt];
							else if(read_cnt >= 8)
							    DataDriveOut_SO = data_outb[15-read_cnt];
							read_cnt = read_cnt + 1;
							if ((ITCRCE && read_cnt == 16) || ~ITCRCE && (read_cnt == 8))
								read_cnt = 0;		
                        end
                    end
                end

                if (PDONE)
                begin
                
                        if (ASPDYB == 1'b0 && ASPO_in[4] == 1'b1)
                            $display("ASPDYB bit is allready programmed");
                        else
                            ASPO[4] = ASPO_in[4];//ASPDYB

                        if (ASPPPB == 1'b0 && ASPO_in[3] == 1'b1)
                            $display("ASPPPB bit is allready programmed");
                        else
                            ASPO[3] = ASPO_in[3];//ASPPPB

                        if (ASPPRM == 1'b0 && ASPO_in[0] == 1'b1)
                            $display("ASPPRM bit is allready programmed");
                        else
                            ASPO[0] = ASPO_in[0];//ASPPRM

                        ASPO[2] = ASPO_in[2];//ASPPWD
						if (ASPPWD == 1'b0 && ASPO_in[2] == 1'b1)
                            $display("ASPPWD bit is already programmed");
                        else
                            ASPO[2] = ASPO_in[2];//ASPPWD
							
                        if (ASPPER == 1'b0 && ASPO_in[1] == 1'b1)
                            $display("ASPPER bit is allready programmed");
                        else
                            ASPO[1] = ASPO_in[1];//ASPPER

                    STR1V[0] = 1'b0;
                    STR1V[1] = 1'b0;
                end
            end

 

            DP_DOWN:
            begin
                rd_fast = 1'b1;
                rd_slow = 1'b0;
                dual    = 1'b0;

                if (CSNeg_ipd && DPDExt_out)
                begin
                    $display("Device is in Deep Power Down Mode");
                    $display("No instructions allowed");
                    #1 DPDExt_out = 1'b0;
                end

                if (falling_edge_RST)
                begin
                    RST_in = 1'b1;
                    #1 RST_in = 1'b0;
                    reseted   = 1'b0;
                end
            end

            SEERC :
            begin
                if (QPI_IT)
                begin
                    rd_fast = 1'b1;
                    rd_slow = 1'b0;
                    dual    = 1'b1;
                    ddr     = 1'b0;
                end
                else
                begin
                    rd_fast = 1'b1;
                    rd_slow = 1'b0;
                    dual    = 1'b0;
                    ddr     = 1'b0;
                end

                if (oe)
                begin
                    any_read = 1'b1;
                    if (Instruct == RDSR1_0_0)
                    begin
                    //Read Status Register 1
                       if (QPI_IT)
                        begin
							if(read_cnt == 0)
							  data_out[7:0] = STR1V;
							else 
							  data_out[7:0] = ~STR1V;
							for (i=0;i<=5;i=i+1)
							begin
								DataDriveOut_Dout[5-i] = data_out[7-i-read_cnt];
							end
							DataDriveOut_SO = data_out[1-read_cnt];
							DataDriveOut_SI = data_out[0-read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;
							
							read_cnt = read_cnt + 1;
							if (read_cnt == (1 + ITCRCE))
							begin
								read_cnt = 0;
							end							
                        end
                        else
                        begin
							DataDriveOut_SO = STR1Vbbar[15-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8 + 8*ITCRCE)
                                read_cnt = 0;
                        end
                    end
                    else if (Instruct == RDSR2_0_0)
                    begin
                        //Read Status Register 2
                        if (QPI_IT)
                        begin
                            data_out[7:0] = STR2V;
                            for (i=0;i<=5;i=i+1)
                            begin
                                DataDriveOut_Dout[5-i] = data_out[7-i-read_cnt];
                            end
                            DataDriveOut_SO = data_out[1-read_cnt];
                            DataDriveOut_SI = data_out[0-read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;

                            read_cnt = read_cnt + 1;
                            if (read_cnt == 1)
                            begin
                                read_cnt = 0;
                            end
                        end
                        else
                        begin
                            DataDriveOut_SO = STR2V[7-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8)
                                read_cnt = 0;
                        end
                    end
                    else if (Instruct == RDARG_C_0)
                    begin
                        READ_ALL_REG(read_addr, RDAR_reg);

                        if (QPI_IT)
                        begin
                            data_out_nibble[0]  = RDAR_reg[7:4];
							data_out_nibble[1]  = RDAR_reg[3:0];
							data_out_nibble[2]  = ~RDAR_reg[7:4];
							data_out_nibble[3]  = ~RDAR_reg[3:0];
							{DataDriveOut_Dout[1:0], DataDriveOut_SO, DataDriveOut_SI} = data_out_nibble[read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;
                            
							read_cnt = read_cnt + 1;							
							if ((ITCRCE && read_cnt == 4) || ~ITCRCE && (read_cnt == 2))
								 read_cnt = 0;	
                        end
                        else
                        begin
						    data_out[7:0]   = RDAR_reg;
							data_outb[7:0]  = ~RDAR_reg;
							if(read_cnt < 8)
							    DataDriveOut_SO = data_out[7-read_cnt];
							else if(read_cnt >= 8)
							    DataDriveOut_SO = data_outb[15-read_cnt];
							read_cnt = read_cnt + 1;
							if ((ITCRCE && read_cnt == 16) || ~ITCRCE && (read_cnt == 8))
								read_cnt = 0;		
                        end
                    end
                end

                if (SEERC_DONE == 1)
                begin
                    STR1V[0] = 1'b0; //RDYBSY

					ReturnSectorID(SectorErased,Address_erase_cnt);

                    // Mirror particular sector erase register to sector erase counter
                    SECV <= {SECCPT_in[SectorErased],SECVAL_in[SectorErased]};
                end
            end

            RESET_STATE:
            begin
            // During Reset,the non-volatile version of the registers is
            // copied to volatile version to provide the default state of
            // the volatile register
                STR1V[7:5] = STR1N[7:5];
                STR1V[1:0] = STR1N[1:0];
                DCRV = 32'h00000000;
                if (RESET_EN)
                begin
                    ICRV = 32'hFFFFFFFF;
                    rd_crc = 0;
                    icrc_out = 32'hFFFFFFFF;
                    icrc_cnt = 0;
                end

                if (Instruct == SFRST_0_0)
                begin
                // The volatile TLPROT bit (CFR1V[0]) and the volatile PPB Lock
                // bit are not changed by the SW RESET
                    CFR1V[7:1] = CFR1N[7:1];
                    STR2V[3] = 1'b0; // DICRCA
                end
                else
                begin
                    CFR1V = CFR1N;
                    
                    if (ASPDYB)
                        DYAV[7:0] = 8'hFF;
                    else
                        DYAV[7:0] = 8'h00;
                   

                    if (~ASPPWD)
                        PPLV[0] = 1'b0;
                    else
                        PPLV[0] = 1'b1;
                end

                CFR2V = CFR2N;
                CFR3V = CFR3N;
                CFR4V = CFR4N;
                CFR5V = CFR5N;
                INC0V = 8'hFF;
                INS0V = 8'hFF;
				INS1V = 8'hFF;
                //Loads the Program Buffer with all ones
                for(i=0;i<=511;i=i+1)
                begin
                    WData[i] = MaxData;
                end

                if (TLPROT == 1'b0)
                begin
                //When BPNV is set to '1'. the LBPROT2-0 bits in Status
                //Register are volatile and will be reseted after
                //reset command
                STR1V[4:2] = STR1N[4:2];
                BP_bits = {STR1V[4],STR1V[3],STR1V[2]};
                change_BP = 1'b1;
                #1 change_BP = 1'b0;
                end
            end

            PGERS_ERROR :
            begin
                if (QPI_IT)
                begin
                    rd_fast = 1'b1;
                    rd_slow = 1'b0;
                    dual    = 1'b1;
                    ddr     = 1'b0;
                end
                else
                begin
                    rd_fast = 1'b1;
                    rd_slow = 1'b0;
                    dual    = 1'b0;
                    ddr     = 1'b0;
                end

                if (oe)
                begin
                    any_read = 1'b1;
                    if (Instruct == RDSR1_0_0)
                    begin
                    //Read Status Register 1
                       if (QPI_IT)
                        begin
							if(read_cnt == 0)
							  data_out[7:0] = STR1V;
							else 
							  data_out[7:0] = ~STR1V;
							for (i=0;i<=5;i=i+1)
							begin
								DataDriveOut_Dout[5-i] = data_out[7-i-read_cnt];
							end
							DataDriveOut_SO = data_out[1-read_cnt];
							DataDriveOut_SI = data_out[0-read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;
							
							read_cnt = read_cnt + 1;
							if (read_cnt == (1 + ITCRCE))
							begin
								read_cnt = 0;
							end							
                        end
                        else
                        begin
							DataDriveOut_SO = STR1Vbbar[15-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8 + 8*ITCRCE)
                                read_cnt = 0;
                        end
                    end
                    else if (Instruct == RDARG_C_0)
                    begin
                        READ_ALL_REG(read_addr, RDAR_reg);

                        if (QPI_IT)
                        begin
                            data_out_nibble[0]  = RDAR_reg[7:4];
							data_out_nibble[1]  = RDAR_reg[3:0];
							data_out_nibble[2]  = ~RDAR_reg[7:4];
							data_out_nibble[3]  = ~RDAR_reg[3:0];
							{DataDriveOut_Dout[1:0], DataDriveOut_SO, DataDriveOut_SI} = data_out_nibble[read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;
                            
							read_cnt = read_cnt + 1;							
							if ((ITCRCE && read_cnt == 4) || ~ITCRCE && (read_cnt == 2))
								 read_cnt = 0;	
                        end
                        else
                        begin
						    data_out[7:0]   = RDAR_reg;
							data_outb[7:0]  = ~RDAR_reg;
							if(read_cnt < 8)
							    DataDriveOut_SO = data_out[7-read_cnt];
							else if(read_cnt >= 8)
							    DataDriveOut_SO = data_outb[15-read_cnt];
								read_cnt = read_cnt + 1;
							if ((ITCRCE && read_cnt == 16) || ~ITCRCE && (read_cnt == 8))
								read_cnt = 0;		
                        end
                    end
                end

                if (falling_edge_write)
                begin
                    if (Instruct == WRDIS_0_0 && ~PRGERR && ~ERSERR)
                    begin
                    // A Clear Status Register (CLPEF_0_0) followed by a Write
                    // Disable (WRDIS_0_0) command must be sent to return the
                    // device to standby state
                        STR1V[1] = 1'b0; //WRPGEN
                    end
                    else if (Instruct == CLECC_0_0)
                    begin
                        ECSV[4] = 0;// 2 bits ECC detection
                        ECSV[3] = 0;// 1 bit ECC correction
                        INS0V[1] = 1;
                        INS0V[0] = 1;
                        ECTV = 16'h0000;
                        EATV = 32'h00000000;
                    end
                    else if (Instruct == CLPEF_0_0)
                    begin
                        STR1V[6] = 0;// PRGERR
                        STR1V[5] = 0;// ERSERR
                        STR1V[0] = 0;// RDYBSY
                    end

                    if (Instruct == SRSTE_0_0)
                    begin
                        RESET_EN = 1;
                    end
                    else
                    begin
                        RESET_EN <= 0;
                    end
                end
            end

            /*BLANK_CHECK :
            begin
                if (rising_edge_BCDONE)
                begin
                    if (NOT_BLANK)
                    begin
                        //Start Sector Erase
                        ESTART = 1'b1;
                        ESTART <= #5 1'b0;
                        ESUSP     = 0;
                        ERES      = 0;
                        INITIAL_CONFIG = 1;
                        STR1V[0] = 1'b1; //RDYBSY
                        Addr = Address;
                    end
                    else
                        STR1V[1] = 1'b1; //WRPGEN
                end
                else
                begin
                    ADDRHILO_SEC(AddrLo, AddrHi, Addr);
                    for (i=AddrLo;i<=AddrHi;i=i+1)
                    begin
                        memory_features_i0.read_mem_w(
                        mem_data,
                        i
                        );
                        if ( mem_data != MaxData)
                            NOT_BLANK = 1'b1;
                    end
                    bc_done = 1'b1;
                end
            end*/

            EVAL_ERS_STAT :
            begin
                if (oe)
                begin
                    any_read = 1'b1;
                    if (Instruct == RDSR1_0_0)
                    begin
                    //Read Status Register 1
                       if (QPI_IT)
                        begin
							if(read_cnt == 0)
							  data_out[7:0] = STR1V;
							else 
							  data_out[7:0] = ~STR1V;
							for (i=0;i<=5;i=i+1)
							begin
								DataDriveOut_Dout[5-i] = data_out[7-i-read_cnt];
							end
							DataDriveOut_SO = data_out[1-read_cnt];
							DataDriveOut_SI = data_out[0-read_cnt];

							if (DATA_STROBE) DataDriveOut_DS = ~DataDriveOut_DS;
							
							read_cnt = read_cnt + 1;
							if (read_cnt == (1 + ITCRCE))
							begin
								read_cnt = 0;
							end							
                        end
                        else
                        begin
							DataDriveOut_SO = STR1Vbbar[15-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8 + 8*ITCRCE)
                                read_cnt = 0;
                        end
                    end
                end

                if (rising_edge_EESDONE)
                begin
                    STR1V[0] = 1'b0;
                    //STR1V[1] = 1'b0;

                    if (ERS_nosucc[sect] == 1'b0)
                    begin
                        STR2V[2] = 1'b1;
                    end
                    else
                        STR2V[2] = 1'b0;
                end
            end

        endcase
        if (falling_edge_write)
        begin
            if (Instruct == SRSTE_0_0 && current_state != DP_DOWN)
                RESET_EN <= 1;
            else
                RESET_EN <= 0;
        end
        
        if (INC0V[7] == 1'b0 || INC0V[4] == 1'b0 || INC0V[1] == 1'b0 
           || INC0V[0] == 1'b0 ) //rising_edge_status_7 ???
        begin
            if (INC0V[7] == 1'b0)
            begin
                if (INC0V[4] == 1'b0 && falling_edge_RDYBSY)
                begin
                    INS0V[4] = 1'b0;
                end
                if (INC0V[1] == 1'b0 && ECSV[1] == 1'b0)
                begin
                    INS0V[1] = 1'b0;
                end
                if (INC0V[0] == 1'b0 && ECSV[0] == 1'b0)
                begin
                    INS0V[0] = 1'b0;
                end
            end
        end
        
        if (ASPO[2]==0 && ASPRDP==0 && PPBLCK==0) //???
            READ_PROTECT = 1'b1;
        else
            READ_PROTECT = 1'b0;

    end
    
    always @(INS0V or INS0V or rising_edge_RST_out or ECSV or falling_edge_RDYBSY or
          rising_edge_SWRST_out or rising_edge_PoweredUp or rising_edge_DPD_out)
    begin
        if (rising_edge_PoweredUp || (rising_edge_RST_out || rising_edge_SWRST_out)
           || rising_edge_DPD_out)
        begin
            INTNeg_zd = 1'b1;
        end
        else if (INC0V[7] == 1'b1)
        begin
            INTNeg_zd = 1'b1;
        end
        else if (INS0V == 8'hFF)
        begin
            INTNeg_zd = 1'b1;
        end
        else if (INC0V[7] == 1'b0)
        begin
            if (INC0V[4] == 1'b0 && falling_edge_RDYBSY)
            begin
                INTNeg_zd = 1'b0;
            end
            if (INC0V[1] == 1'b0 && ECSV[4] == 1'b1 )
            begin
                INTNeg_zd = 1'b0;
            end
            if (INC0V[0] == 1'b0 && ECSV[3] == 1'b1 )
            begin
                INTNeg_zd = 1'b0;
            end
        end
    
    end
    
    
    always @(posedge CSNeg_ipd)
    begin
        //Output Disable Control
        SOut_zd                = 1'bZ;
        SIOut_zd               = 1'bZ;
        DataDriveOut_SO        = 1'bZ;
        DataDriveOut_SI        = 1'bZ;
        Dout_zd                = 8'bZ;
        DataDriveOut_Dout      = 2'bZ;
        DS_zd                  = 1'bZ;
        DataDriveOut_DS        = 1'bZ;
    end

    /*always @(change_TBPARM, UniformSec, posedge PoweredUp)
    begin
        if (UniformSec == 1'b0)
        begin
            if (CFR1V[6] == 1'b0)    // 4KB is split
            begin
               if (TB4KBS_NV == 0)  // TB4KBS_NV - 4K is at top of address space
               begin
                   TopBoot     = 0;
                   BottomBoot  = 1;
                   UniformSec = 0;
               end
               else
               begin
                   TopBoot     = 1;
                   BottomBoot  = 0;
                   UniformSec = 0;
               end
            end
            else if (CFR1V[6] == 1'b1) 
            begin
                 TopBoot     = 1;
                 BottomBoot  = 1;
                 UniformSec = 0;
            end
        end   
        else
        begin
            UniformSec = 1;
        end
    end
	*/
	

    always @(posedge change_BP)
    begin
        case (STR1V[4:2])

            3'b000:
            begin
                Sec_Prot[SecNumHyb:0] = {8192{1'b0}};
            end

            3'b001:
            begin
                if (UniformSec) // Uniform Sector Architecture
                begin
                    if (~TBPROT_NV)  // LBPROT starts at Top
                    begin
                        Sec_Prot[SecNumUni:(SecNumUni+1)*63/64] =   {4{1'b1}};
                        Sec_Prot[(SecNumUni+1)*63/64-1 : 0]     = {252{1'b0}};
                    end
                    else
                    begin
                        Sec_Prot[(SecNumUni+1)/64-1 : 0]       =   {4{1'b1}};
                        Sec_Prot[SecNumUni : (SecNumUni+1)/64] = {252{1'b0}};
                    end
                end
                else if (~UniformSec && SP4KBS_NV)// Hybrid Sector Architecture
                begin
                    if (~TBPROT_NV)  // LBPROT starts at Top
                    begin
                        Sec_Prot[SecNumHyb:(SecNumHyb-19)] =   {20{1'b1}};
                        Sec_Prot[(SecNumHyb-20) : 0]     = {268{1'b0}};
                    end
                    else
                    begin
                        Sec_Prot[19 : 0]       =   {20{1'b1}};
                        Sec_Prot[SecNumHyb : (SecNumHyb-20)] = {268{1'b0}};
                    end
                end
                else// Hybrid Sector Architecture
                begin
                    if(TB4KBS_NV)  // 4 KB Physical Sectors at Top
                    begin
                        if (~TBPROT_NV)  // LBPROT starts at Top
                        begin
                            Sec_Prot[SecNumHyb:(SecNumHyb-31)*63/64]= {36{1'b1}};
                            Sec_Prot[(SecNumHyb-31)*63/64-1 : 0]   = {252{1'b0}};
                        end
                        else
                        begin
                            Sec_Prot[(SecNumHyb-31)/64-1 : 0]      =   {4{1'b1}};
                            Sec_Prot[SecNumHyb :(SecNumHyb-31)/64] = {284{1'b0}};
                        end
                    end
                    else          // 4 KB Physical Sectors at Bottom
                    begin
                        if (~TBPROT_NV)  // LBPROT starts at Top
                        begin
                            Sec_Prot[SecNumHyb:(SecNumHyb-31)*63/64+8] =
                                                                      {28{1'b1}};
                            Sec_Prot[(SecNumHyb-31)*63/64+7 : 0]   = {260{1'b0}};
                        end
                        else            // LBPROT starts at Bottom
                        begin
                            Sec_Prot[(SecNumHyb-31)/64+7 : 0]      =  {12{1'b1}};
                            Sec_Prot[SecNumHyb:(SecNumHyb-31)/64+8]= {276{1'b0}};
                        end
                    end
                end
            end

            3'b010:
            begin
                if (UniformSec) // Uniform Sector Architecture
                begin
                    if (~TBPROT_NV)  // LBPROT starts at Top
                    begin
                        Sec_Prot[SecNumUni : (SecNumUni+1)*31/32] = {8{1'b1}};
                        Sec_Prot[(SecNumUni+1)*31/32-1 : 0]       = {248{1'b0}};
                    end
                    else            // LBPROT starts at Bottom
                    begin
                        Sec_Prot[(SecNumUni+1)/32-1 : 0]       = {8{1'b1}};
                        Sec_Prot[SecNumUni : (SecNumUni+1)/32] = {248{1'b0}};
                    end
                end
                else if (~UniformSec &&  SP4KBS_NV)// Hybrid Sector Architecture
                begin
                    if (~TBPROT_NV)  // LBPROT starts at Top
                    begin
                        Sec_Prot[SecNumHyb:(SecNumHyb-23)]= {24{1'b1}};
                        Sec_Prot[(SecNumHyb-24) : 0]   = {264{1'b0}};
                    end
                    else
                    begin
                        Sec_Prot[23 : 0]      =   {24{1'b1}};
                        Sec_Prot[SecNumHyb : 24] = {264{1'b0}};
                    end
                end
                else// Hybrid Sector Architecture
                begin
                    if(TB4KBS_NV)  // 4 KB Physical Sectors at Top
                    begin
                        if (~TBPROT_NV)  // LBPROT starts at Top
                        begin
                            Sec_Prot[SecNumHyb:(SecNumHyb-31)*31/32]= {40{1'b1}};
                            Sec_Prot[(SecNumHyb-31)*31/32-1 : 0]   = {248{1'b0}};
                        end
                        else
                        begin
                            Sec_Prot[(SecNumHyb-31)/32-1 : 0]      =   {8{1'b1}};
                            Sec_Prot[SecNumHyb :(SecNumHyb-31)/32] = {280{1'b0}};
                        end
                    end
                    else          // 4 KB Physical Sectors at Bottom
                    begin
                        if (~TBPROT_NV)  // LBPROT starts at Top
                        begin
                            Sec_Prot[SecNumHyb:(SecNumHyb-31)*31/32+8] =
                                                                      {32{1'b1}};
                            Sec_Prot[(SecNumHyb-31)*31/32+7 : 0]   = {256{1'b0}};
                        end
                        else            // LBPROT starts at Bottom
                        begin
                            Sec_Prot[(SecNumHyb-31)/32+7 : 0]      =  {16{1'b1}};
                            Sec_Prot[SecNumHyb:(SecNumHyb-31)/32+8]= {272{1'b0}};
                        end
                    end
                end
            end

            3'b011:
            begin
                if (UniformSec) // Uniform Sector Architecture
                begin
                    if (~TBPROT_NV)  // LBPROT starts at Top
                    begin
                        Sec_Prot[SecNumUni : (SecNumUni+1)*15/16] = {16{1'b1}};
                        Sec_Prot[(SecNumUni+1)*15/16-1 : 0]       = {240{1'b0}};
                    end
                    else            // LBPROT starts at Bottom
                    begin
                        Sec_Prot[(SecNumUni+1)/16-1 : 0]       = {16{1'b1}};
                        Sec_Prot[SecNumUni : (SecNumUni+1)/16] = {240{1'b0}};
                    end
                end
                else if (~UniformSec &&  SP4KBS_NV)// Hybrid Sector Architecture
                begin
                    if (~TBPROT_NV)  // LBPROT starts at Top
                    begin
                        Sec_Prot[SecNumHyb:(SecNumHyb-31)]= {32{1'b1}};
                        Sec_Prot[(SecNumHyb-32) : 0]   = {256{1'b0}};
                    end
                    else
                    begin
                        Sec_Prot[31 : 0]      =  {32{1'b1}};
                        Sec_Prot[SecNumHyb : 32] = {256{1'b0}};
                    end
                end
                else// Hybrid Sector Architecture
                begin
                    if(TB4KBS_NV)  // 4 KB Physical Sectors at Top
                    begin
                        if (~TBPROT_NV)  // LBPROT starts at Top
                        begin
                            Sec_Prot[SecNumHyb:(SecNumHyb-31)*15/16]= {48{1'b1}};
                            Sec_Prot[(SecNumHyb-31)*15/16-1 : 0]   = {240{1'b0}};
                        end
                        else
                        begin
                            Sec_Prot[(SecNumHyb-31)/16-1 : 0]      =  {16{1'b1}};
                            Sec_Prot[SecNumHyb :(SecNumHyb-31)/16] = {272{1'b0}};
                        end
                    end
                    else          // 4 KB Physical Sectors at Bottom
                    begin
                        if (~TBPROT_NV)  // LBPROT starts at Top
                        begin
                            Sec_Prot[SecNumHyb:(SecNumHyb-31)*15/16+8] =
                                                                     {40{1'b1}};
                            Sec_Prot[(SecNumHyb-31)*15/16+7 : 0]   = {248{1'b0}};
                        end
                        else            // LBPROT starts at Bottom
                        begin
                            Sec_Prot[(SecNumHyb-31)/16+7 : 0]      =  {24{1'b1}};
                            Sec_Prot[SecNumHyb:(SecNumHyb-31)/16+8]= {264{1'b0}};
                        end
                    end
                end
            end

            3'b100:
            begin
                if (UniformSec) // Uniform Sector Architecture
                begin
                    if (~TBPROT_NV)  // LBPROT starts at Top
                    begin
                        Sec_Prot[SecNumUni : (SecNumUni+1)*7/8] = {32{1'b1}};
                        Sec_Prot[(SecNumUni+1)*7/8-1 : 0]       = {224{1'b0}};
                    end
                    else            // LBPROT starts at Bottom
                    begin
                        Sec_Prot[(SecNumUni+1)/8-1 : 0]       = {32{1'b1}};
                        Sec_Prot[SecNumUni : (SecNumUni+1)/8] = {224{1'b0}};
                    end
                end
                else if (~UniformSec &&  SP4KBS_NV)// Hybrid Sector Architecture
                begin
                    if (~TBPROT_NV)  // LBPROT starts at Top
                    begin
                        Sec_Prot[SecNumHyb:(SecNumHyb-47)]= {48{1'b1}};
                        Sec_Prot[(SecNumHyb-48):0]   = {240{1'b0}};
                    end
                    else
                    begin
                        Sec_Prot[47 : 0]      =  {48{1'b1}};
                        Sec_Prot[SecNumHyb : 47] = {240{1'b0}};
                    end
                end
                else// Hybrid Sector Architecture
                begin
                    if(TB4KBS_NV)  // 4 KB Physical Sectors at Top
                    begin
                        if (~TBPROT_NV)  // LBPROT starts at Top
                        begin
                            Sec_Prot[SecNumHyb:(SecNumHyb-31)*7/8]= {64{1'b1}};
                            Sec_Prot[(SecNumHyb-31)*7/8-1 : 0]   = {224{1'b0}};
                        end
                        else
                        begin
                            Sec_Prot[(SecNumHyb-31)/8-1 : 0]      =  {32{1'b1}};
                            Sec_Prot[SecNumHyb :(SecNumHyb-31)/8] = {256{1'b0}};
                        end
                    end
                    else          // 4 KB Physical Sectors at Bottom
                    begin
                        if (~TBPROT_NV)  // LBPROT starts at Top
                        begin
                            Sec_Prot[SecNumHyb:(SecNumHyb-31)*7/8+8] =
                                                                     {56{1'b1}};
                            Sec_Prot[(SecNumHyb-31)*7/8+7 : 0]     = {232{1'b0}};
                        end
                        else            // LBPROT starts at Bottom
                        begin
                            Sec_Prot[(SecNumHyb-31)/8+7 : 0]       =  {40{1'b1}};
                            Sec_Prot[SecNumHyb:(SecNumHyb-31)/8+8] = {248{1'b0}};
                        end
                    end
                end
            end

            3'b101:
            begin
                if (UniformSec) // Uniform Sector Architecture
                begin
                    if (~TBPROT_NV)  // LBPROT starts at Top
                    begin
                        Sec_Prot[SecNumUni : (SecNumUni+1)*3/4] = {64{1'b1}};
                        Sec_Prot[(SecNumUni+1)*3/4-1 : 0]       = {192{1'b0}};
                    end
                    else            // LBPROT starts at Bottom
                    begin
                        Sec_Prot[(SecNumUni+1)/4-1 : 0]       = {64{1'b1}};
                        Sec_Prot[SecNumUni : (SecNumUni+1)/4] = {192{1'b0}};
                    end
                end
                else if (~UniformSec &&  SP4KBS_NV)// Hybrid Sector Architecture
                begin
                    if (~TBPROT_NV)  // LBPROT starts at Top
                    begin
                        Sec_Prot[SecNumHyb:(SecNumHyb-79)]= {80{1'b1}};
                        Sec_Prot[(SecNumHyb-80): 0]   = {208{1'b0}};
                    end
                    else
                    begin
                        Sec_Prot[79 : 0]      =  {80{1'b1}};
                        Sec_Prot[SecNumHyb :80] = {208{1'b0}};
                    end
                end
                else// Hybrid Sector Architecture
                begin
                    if(TB4KBS_NV)  // 4 KB Physical Sectors at Top
                    begin
                        if (~TBPROT_NV)  // LBPROT starts at Top
                        begin
                            Sec_Prot[SecNumHyb:(SecNumHyb-31)*3/4]= {96{1'b1}};
                            Sec_Prot[(SecNumHyb-31)*3/4-1 : 0]   = {192{1'b0}};
                        end
                        else
                        begin
                            Sec_Prot[(SecNumHyb-31)/4-1 : 0]      =  {64{1'b1}};
                            Sec_Prot[SecNumHyb :(SecNumHyb-31)/4] = {224{1'b0}};
                        end
                    end
                    else          // 4 KB Physical Sectors at Bottom
                    begin
                        if (~TBPROT_NV)  // LBPROT starts at Top
                        begin
                            Sec_Prot[SecNumHyb:(SecNumHyb-31)*3/4+8] =
                                                                     {88{1'b1}};
                            Sec_Prot[(SecNumHyb-31)*3/4+7 : 0]     = {200{1'b0}};
                        end
                        else            // LBPROT starts at Bottom
                        begin
                            Sec_Prot[(SecNumHyb-31)/4+7 : 0]       =  {72{1'b1}};
                            Sec_Prot[SecNumHyb:(SecNumHyb-31)/4+8] = {216{1'b0}};
                        end
                    end
                end
            end

            3'b110:
            begin
                if (UniformSec) // Uniform Sector Architecture
                begin
                    if (~TBPROT_NV)  // LBPROT starts at Top
                    begin
                        Sec_Prot[SecNumUni : (SecNumUni+1)/2] = {128{1'b1}};
                        Sec_Prot[(SecNumUni+1)/2-1 : 0]       = {128{1'b0}};
                    end
                    else            // LBPROT starts at Bottom
                    begin
                        Sec_Prot[(SecNumUni+1)/2-1 : 0]       = {128{1'b1}};
                        Sec_Prot[SecNumUni : (SecNumUni+1)/2] = {128{1'b0}};
                    end
                end
                else if (~UniformSec &&  SP4KBS_NV)// Hybrid Sector Architecture
                begin
                    if (~TBPROT_NV)  // LBPROT starts at Top
                    begin
                        Sec_Prot[SecNumHyb:(SecNumHyb-143)] = {144{1'b1}};
                        Sec_Prot[(SecNumHyb-144) : 0]     = {144{1'b0}};
                    end
                    else
                    begin
                        Sec_Prot[143 : 0]      = {144{1'b1}};
                        Sec_Prot[SecNumHyb : 144] = {144{1'b0}};
                    end
                end
                else// Hybrid Sector Architecture
                begin
                    if(TB4KBS_NV)  // 4 KB Physical Sectors at Top
                    begin
                        if (~TBPROT_NV)  // LBPROT starts at Top
                        begin
                            Sec_Prot[SecNumHyb:(SecNumHyb-31)/2] = {160{1'b1}};
                            Sec_Prot[(SecNumHyb-31)/2-1 : 0]     = {128{1'b0}};
                        end
                        else
                        begin
                            Sec_Prot[(SecNumHyb-31)/2-1 : 0]      = {128{1'b1}};
                            Sec_Prot[SecNumHyb :(SecNumHyb-31)/2] = {160{1'b0}};
                        end
                    end
                    else          // 4 KB Physical Sectors at Bottom
                    begin
                        if (~TBPROT_NV)  // LBPROT starts at Top
                        begin
                            Sec_Prot[SecNumHyb:(SecNumHyb-31)/2+8] = {152{1'b1}};
                            Sec_Prot[(SecNumHyb-31)/2+7 : 0]       = {136{1'b0}};
                        end
                        else            // LBPROT starts at Bottom
                        begin
                            Sec_Prot[(SecNumHyb-31)/2+7 : 0]       = {136{1'b1}};
                            Sec_Prot[SecNumHyb:(SecNumHyb-31)/2+8] = {152{1'b0}};
                        end
                    end
                end
            end

            3'b111:
            begin
                Sec_Prot[SecNumHyb:0] =  {8192{1'b1}};
            end
        endcase
    end

    always @(CFR3V[4])
    begin
        if (CFR3V[4] == 1'b0)
        begin
            PageSize = 255;
            PageNum  = PageNum256;
        end
        else
        begin
            PageSize = 255;
            PageNum  = PageNum256;
        end
    end
    
    ////////////////////////////////////////////////////////////////////////
    // autoboot control logic
    ////////////////////////////////////////////////////////////////////////
    always @(rising_edge_SCK_ipd or current_state_event)
    begin
        if(current_state == AUTOBOOT)
        begin
            if (rising_edge_SCK_ipd)
            begin
                if (start_delay > 0)
                    start_delay = start_delay - 1;
            end

            if (start_delay == 0)
            begin
                start_autoboot = 1;
            end
        end
    end

	task GEN_CRC_RD8;  //For CRC8
		input   [7:0] data_in;
        begin
				//$display("crc_reg8_data = 0x%h, data_in = 0x%h", crc_reg8_data, data_in);
				crc_reg8_data = crc_reg8_data ^ data_in;
				//$display("crc_reg8_data after xor = 0x%h", crc_reg8_data);
				for (i = 0; i < 8; i++)
				begin
					if (crc_reg8_data[7])
					begin
						crc_reg8_data = (crc_reg8_data << 1) ^ polynomial8;
						//$display("crc_reg8_data= 0x%h, i=%d", crc_reg8_data, i);
					end
					else 
					begin
						crc_reg8_data = crc_reg8_data << 1;
						//$display("crc_reg8_data = 0x%h, i=%d", crc_reg8_data, i);
					end
				end 
        end
    endtask
	
	task GEN_CRC_PGM8;  //For CRC8
		input   [7:0] data_in;
        begin
			//$display("MO: crc_reg8_pgm_data = 0x%h, data_in = 0x%h", crc_reg8_pgm_data, data_in);
			crc_reg8_pgm_data = crc_reg8_pgm_data ^ data_in;
			//$display("MO: crc_reg8_pgm_data after xor = 0x%h", crc_reg8_pgm_data);
			for (i = 0; i < 8; i++)
			begin
				if (crc_reg8_pgm_data[7])
				begin
					crc_reg8_pgm_data = (crc_reg8_pgm_data << 1) ^ polynomial8;
					//$display("MO: crc_reg8_pgm_data= 0x%h, i=%d", crc_reg8_pgm_data, i);
				end
				else 
				begin
					crc_reg8_pgm_data = crc_reg8_pgm_data << 1;
					//$display("MO: crc_reg8_pgm_data= 0x%h, i=%d", crc_reg8_pgm_data, i);
				end
			end
        end
    endtask
	

	task GEN_CRC_PGM16;  //For CRC8
		input   [15:0] data_in;
        begin
			//$display("MO: crc_reg16_pgm_data = 0x%h, data_in = 0x%h", crc_reg16_pgm_data, data_in);
			crc_reg16_pgm_data = crc_reg16_pgm_data ^ data_in;
			//$display("MO: crc_reg16_pgm_data after xor = 0x%h", crc_reg16_pgm_data);
			for (i = 0; i < 16; i++)
			begin
				if (crc_reg16_pgm_data[15])
				begin
					crc_reg16_pgm_data = (crc_reg16_pgm_data << 1) ^ polynomial16;
					//$display("MO: crc_reg16_pgm_data= 0x%h, i=%d", crc_reg16_pgm_data, i);
				end
				else 
				begin
					crc_reg16_pgm_data = crc_reg16_pgm_data << 1;
					//$display("MO: crc_reg16_pgm_data= 0x%h, i=%d", crc_reg16_pgm_data, i);
				end
			end
        end
    endtask
	

	task GEN_CRC_RD16;  //For CRC16
		input   [15:0] data_in;
        begin
			//$display("MO: crc_reg16_data = 0x%h, data_in = 0x%h", crc_reg16_data, data_in);
			crc_reg16_data = crc_reg16_data ^ data_in;
			//$display("MO: crc_reg16_data after xor = 0x%h", crc_reg16_data);
			for (i = 0; i < 16; i++)
			begin
				if (crc_reg16_data[15])
				begin
					crc_reg16_data = (crc_reg16_data << 1) ^ polynomial16;
					//$display("MO: crc_reg16_data= 0x%h, i=%d", crc_reg16_data, i);
				end
				else 
				begin
					crc_reg16_data = crc_reg16_data << 1;
					//$display("MO: crc_reg16_data= 0x%h, i=%d", crc_reg16_data, i);
				end
			end
        end
    endtask




	task CHECK_CRC_CMD;
		input integer size; // can be 1, 4 and 5 for cmd+addr(3or4)
		input integer crc8; // 1 = crc8, 0=crc16
		reg   [7:0] data_in[0:5];
        begin
		    crc_pass_cmd = 0; 
			crc_reg8_cmd = 8'hFF;
			crc_reg16_cmd = 16'hFFFF;

			if (QPI_IT && ~SDRDDR)
			begin
				data_in[0] = opcode;
            	data_in[1] = opcode;

				if (size == 5)
				begin
					data_in[2] = Address[31:24];
					data_in[3] = Address[23:16];
					data_in[4] = Address[15:8];
					data_in[5] = Address[7:0];
				end
				else if (size == 4)
				begin
					data_in[2] = Address[23:16];
					data_in[3] = Address[15:8];
					data_in[4] = Address[7:0];
					data_in[5] = 8'h00;
				end
			end
			else
			begin
				data_in[0] = opcode;

				if (size == 5)
				begin
					data_in[1] = Address[31:24];
					data_in[2] = Address[23:16];
					data_in[3] = Address[15:8];
					data_in[4] = Address[7:0];
					data_in[5] = 8'h00;
				end
				else if (size == 4)
				begin
					data_in[1] = Address[23:16];
					data_in[2] = Address[15:8];
					data_in[3] = Address[7:0];
					data_in[4] = 8'h00;
					data_in[5] = 8'h00;
				end
			end
			
		    if(crc8  == 1)   // When CRC8 polynomial is used
			begin  
				for (j = 0; j < size; j++) 
				begin
				    //$display("MO: data_in[%d] = 0x%h", j, data_in[j]);
					crc_reg8_cmd = crc_reg8_cmd ^ data_in[j];
					//$display("MO: crc_reg8_cmd after xor = 0x%h", crc_reg8_cmd);
					for (i = 0; i < 8; i++)
					begin
						if (crc_reg8_cmd[7])
						begin
							crc_reg8_cmd = (crc_reg8_cmd << 1) ^ polynomial8;
							//$display("MO: crc_reg8_cmd= 0x%h, i=%d", crc_reg8_cmd, i);
					    end
						else 
						begin
							crc_reg8_cmd = crc_reg8_cmd << 1;
							//$display("MO: crc_reg8_cmd= 0x%h, i=%d", crc_reg8_cmd, i);
						end
					end
				end
			    crc_reg8_cmd = ~crc_reg8_cmd;
				//$display("MO: ~crc_reg8_cmd = 0x%h", crc_reg8_cmd);
				if(crc_reg8_cmd == Intfcrc_value[7:0]) 
				   crc_pass_cmd = 1; 
		    end
			else  // CRC 16
			begin 
				data_in[0] = opcode; 
				data_in[1] = opcode; 
				data_in[2] = Address[31:24];
				data_in[3] = Address[23:16];
				data_in[4] = Address[15:8];
				data_in[5] = Address[7:0];
				for (j = 0; j < size; j++) // size = 1 - 1, size =4/5 - 3 
				begin
					//$display("Mo: data_in[%d] = 0x%h", j, {data_in[2*j],data_in[2*j+1]);
					crc_reg16_cmd = crc_reg16_cmd ^ {data_in[2*j],data_in[2*j+1]};
					//$display("Mo: crc_reg16 after xor = 0x%h", crc_reg16);
					for (i = 0; i < 16; i++)
					begin
						if (crc_reg16_cmd[15])
						begin
							crc_reg16_cmd = (crc_reg16_cmd << 1) ^ polynomial16;
							//$display("Mo: crc_reg16= 0x%h, i=%d", crc_reg16, i);
						end
						else 
						begin
							crc_reg16_cmd = crc_reg16_cmd << 1;
							//$display("Mo: crc_reg16= 0x%h, i=%d", crc_reg16, i);
						end
					end
				end
                if(crc_reg16_cmd == Intfcrc_value[15:0]) 
				   crc_pass_cmd = 1; 				
			end
        end
    endtask
	

    task READMEM;
            input integer Address;
            input integer SecAddr;
            reg [15:0] ReadData;
        begin
            memory_features_i0.read_mem_w(
                mem_data,
                Address);
            if (mem_data != -1)
            begin
                if (corrupt_Sec[SecAddr] == 1)
                begin
                    if (mem_data == MaxData)
					begin	
                        ReadData = 8'hx;
					end
                    else if (mem_data == MaxData+1)
                    begin
                        mem_data = MaxData;
                        ReadData = mem_data;
                    end
                    else
                        ReadData = mem_data;
                end
                else
                    ReadData = mem_data;
            end
            else
			begin
                ReadData = 8'bx;
			end

            OutputD = ReadData;
        end
    endtask

    // Procedure ADDRHILO_SEC
    task ADDRHILO_SEC;
    inout   AddrLOW;
    inout   AddrHIGH;
    input   Addr;
    integer AddrLOW;
    integer AddrHIGH;
    integer Addr;
    integer sector;
    begin
        if (UniformSec == 1'b0) //Hybrid Sector Architecture
        begin
            if ( SP4KBS_NV == 0)//Top or Botton
            begin
                if (TB4KBS_NV == 0) //4KB Sectors at Bottom
                begin
                    if (Addr/(SecSize256+1) == 0)
                    begin
                        if (Addr/(SecSize4+1) < 32 &&
                           ( Instruct == ERO04_4_0))  //4KB Sectors
                        begin
                            sector   = Addr/(SecSize4+1);
                            AddrLOW  = sector*(SecSize4+1);
                            AddrHIGH = sector*(SecSize4+1) + SecSize4;
                        end
                        else
                        begin
                            AddrLOW  = 32*(SecSize4+1);
                            AddrHIGH = SecSize256;
                        end
                    end
                    else
                    begin
                        sector   = Addr/(SecSize256+1);
                        AddrLOW  = sector*(SecSize256+1);
                        AddrHIGH = sector*(SecSize256+1) + SecSize256;
                    end
                end
                else  //4KB Sectors at Top
                begin
                    if (Addr/(SecSize256+1) == 255)
                    begin
                        if (Addr >  (AddrRANGE - 32*(SecSize4+1))&&
                           (Instruct == ERO04_4_0)) //4KB Sectors
                        begin
                            sector   = 256 +
                               (Addr-(AddrRANGE + 1 - 32*(SecSize4+1)))/(SecSize4+1);
                            AddrLOW  = AddrRANGE + 1 - 32*(SecSize4+1) +
                               (sector-256)*(SecSize4+1);
                            AddrHIGH = AddrRANGE + 1 - 32*(SecSize4+1) +
                                       (sector-256)*(SecSize4+1) + SecSize4;
                        end
                        else
                        begin
                            AddrLOW  = 255*(SecSize256+1);
                            AddrHIGH = AddrRANGE - 32*(SecSize4+1);
                        end
                    end
                    else
                    begin
                        sector   = Addr/(SecSize256+1);
                        AddrLOW  = sector*(SecSize256+1);
                        AddrHIGH = sector*(SecSize256+1) + SecSize256;
                    end
                end
            end
            else if ( SP4KBS_NV == 1'b1) //Top and Botton
            begin
                if (Addr/(SecSize256+1) == 0)
                    begin
                        if (Addr/(SecSize4+1) < 16 &&
                           (Instruct == ERO04_4_0))  //4KB Sectors
                        begin
                            sector   = Addr/(SecSize4+1);
                            AddrLOW  = sector*(SecSize4+1);
                            AddrHIGH = sector*(SecSize4+1) + SecSize4;
                        end
                        else
                        begin
                            AddrLOW  = 16*(SecSize4+1);
                            AddrHIGH = SecSize256;
                        end
                    end
                    else if (Addr/(SecSize256+1) == 272)
                    begin
                        if (Addr >  (AddrRANGE - 16*(SecSize4+1))&&
                           (Instruct == ERO04_4_0)) //4KB Sectors
                        begin
                            sector   = 256 +
                               (Addr-(AddrRANGE + 1 - 16*(SecSize4+1)))/(SecSize4+1);
                            AddrLOW  = AddrRANGE + 1 - 16*(SecSize4+1) +
                               (sector-256)*(SecSize4+1);
                            AddrHIGH = AddrRANGE + 1 - 16*(SecSize4+1) +
                                       (sector-256)*(SecSize4+1) + SecSize4;
                        end
                        else
                        begin
                            AddrLOW  = 255*(SecSize256+1);
                            AddrHIGH = AddrRANGE - 16*(SecSize4+1);
                        end
                    end
                    else
                    begin
                        sector   = Addr/(SecSize256+1);
                        AddrLOW  = sector*(SecSize256+1);
                        AddrHIGH = sector*(SecSize256+1) + SecSize256;
                    end
            end
        end
        else   //Uniform Sector Architecture
        begin
            sector   = Addr/(SecSize256+1);
            AddrLOW  = sector*(SecSize256+1);
            AddrHIGH = sector*(SecSize256+1) + SecSize256;
        end
    end
    endtask

    // Procedure ADDRHILO_PG
    task ADDRHILO_PG;
    inout  AddrLOW;
    inout  AddrHIGH;
    input   Addr;
    integer AddrLOW;
    integer AddrHIGH;
    integer Addr;
    integer page;
    begin
        page = Addr / (PageSize + 1);
        AddrLOW = page * (PageSize + 1);
        AddrHIGH = page * (PageSize + 1) + PageSize;
    end
    endtask

    // Procedure ReturnSectorID
    task ReturnSectorID;
    inout   sect;
    input   Address;
    integer sect;
    integer Address;
    integer conv;
    integer HybAddrHi;
    integer HybAddrLow;
    begin
        if (UniformSec == 1'b0) //Hybrid Sector Architecture 
        begin
            if  (CFR1V[6] == 1'b0) 
            begin
                conv = Address / (SecSize256+1);
                if (!TopBoot && BottomBoot)
                begin
                    if (conv == 0)  //4KB Sectors
                    begin
                        param_sec_write_time = 1'b0;
                        HybAddrHi = 32*(SecSize4+1) - 1;
                
                        if (Address <= HybAddrHi)
                            sect = Address/(SecSize4+1);
                        else
                            sect = 32;
                    end
                    else
                    begin
                        sect = conv + 32;
                        param_sec_write_time = 1'b1;
                    end
                end
                else if (TopBoot && !BottomBoot)
                begin
                    if (conv == 255)       //4KB Sectors
                    begin
                        param_sec_write_time = 1'b0;
                        HybAddrLow = AddrRANGE + 1 - 32*(SecSize4+1);
                
                        if (Address < HybAddrLow)
                            sect = 255;
                        else
                            sect = 256 + (Address - HybAddrLow) / (SecSize4+1);
                    end
                    else
                    begin
                        sect = conv;
                        param_sec_write_time = 1'b1;
                    end
                end
             end
             else if  (CFR1V[6] == 1'b1) 
             begin
                 conv = Address / (SecSize256+1);
                 if (conv == 0)  //4KB Sectors
                 begin
                    param_sec_write_time = 1'b0;
                    HybAddrHi = 16*(SecSize4+1) - 1;
                    if (Address <= HybAddrHi)
                      sect = Address/(SecSize4+1);
                    else
                      sect = 17;
                 end
                 else if (conv == 255)       //4KB Sectors
                 begin
                    param_sec_write_time = 1'b0;
                      HybAddrLow = AddrRANGE + 1 - 16*(SecSize4+1);
                    if (Address < HybAddrLow)
                      sect = 271;
                    else
                      sect = 272 + (Address - HybAddrLow) / (SecSize4+1);
                 end
                 else if (conv > 0 && conv < 255)
                 begin
                      sect = conv + 16;
                      param_sec_write_time = 1'b1;
                 end
             end
        end
        else  //Uniform Sector Architecture
        begin
            sect = Address/(SecSize256+1);
            param_sec_write_time = 1'b1;
        end
    end
    endtask

    task READ_ALL_REG;
        input integer Addr;
        inout integer RDAR_reg;
    begin

        if (Addr == 32'h00000000)
            RDAR_reg = STR1N;
        else if (Addr == 32'h00000002)
            RDAR_reg = CFR1N;
        else if (Addr == 32'h00000003)
            RDAR_reg = CFR2N;
        else if (Addr == 32'h00000004)
            RDAR_reg = CFR3N;
        else if (Addr == 32'h00000005)
            RDAR_reg = CFR4N;
        else if (Addr == 32'h00000006)
            RDAR_reg = CFR5N;
		else if (Addr == 32'h00000008)
            RDAR_reg = ICEN;
        else if (Addr == 32'h00000020)
        begin
            if (ASPPWD)
                RDAR_reg = PWDO[7:0];
            else
                RDAR_reg = 8'bXX;
        end
        else if (Addr == 32'h00000021)
        begin
            if (ASPPWD)
                RDAR_reg = PWDO[15:8];
            else
                RDAR_reg = 8'bXX;
        end
        else if (Addr == 32'h00000022)
        begin
            if (ASPPWD)
                RDAR_reg = PWDO[23:16];
            else
                RDAR_reg = 8'bXX;
        end
        else if (Addr == 32'h00000023)
        begin
            if (ASPPWD)
                RDAR_reg = PWDO[31:24];
            else
                RDAR_reg = 8'bXX;
        end
        else if (Addr == 32'h00000024)
        begin
            if (ASPPWD)
                RDAR_reg = PWDO[39:32];
            else
                RDAR_reg = 8'bXX;
        end
        else if (Addr == 32'h00000025)
        begin
            if (ASPPWD)
                RDAR_reg = PWDO[47:40];
            else
                RDAR_reg = 8'bXX;
        end
        else if (Addr == 32'h00000026)
        begin
            if (ASPPWD)
                RDAR_reg = PWDO[55:48];
            else
                RDAR_reg = 8'bXX;
        end
        else if (Addr == 32'h00000027)
        begin
            if (ASPPWD)
                RDAR_reg = PWDO[63:56];
            else
                RDAR_reg = 8'bXX;
        end
        else if (Addr == 32'h00000030)
            RDAR_reg = ASPO[7:0];
        else if (Addr == 32'h00000031)
            RDAR_reg = ASPO[15:8];
        else if (Addr == 32'h00000042)
            RDAR_reg = ATBN[7:0];
        else if (Addr == 32'h00000043)
            RDAR_reg = ATBN[15:8];
        else if (Addr == 32'h00000044)
            RDAR_reg = ATBN[23:16];
        else if (Addr == 32'h00000045)
            RDAR_reg = ATBN[31:24];
        else if (Addr == 32'h00000050)
            RDAR_reg = EFX0O[7:0];
        else if (Addr == 32'h00000051)
            RDAR_reg = EFX0O[15:8];
        else if (Addr == 32'h00000052)
            RDAR_reg = EFX1O[7:0];
        else if (Addr == 32'h00000053)
            RDAR_reg = EFX1O[15:8];
        else if (Addr == 32'h00000054)
            RDAR_reg = EFX2O[7:0];
        else if (Addr == 32'h00000055)
            RDAR_reg = EFX2O[15:8];
        else if (Addr == 32'h00000056)
            RDAR_reg = EFX3O[7:0];
        else if (Addr == 32'h00000057)
            RDAR_reg = EFX3O[15:8];
        else if (Addr == 32'h00000058)
            RDAR_reg = EFX4O[7:0];
        else if (Addr == 32'h00000059)
            RDAR_reg = EFX4O[15:8];
        else if (Addr == 32'h00000079)
            RDAR_reg = UID_reg[7:0];
        else if (Addr == 32'h0000007A)
            RDAR_reg = UID_reg[15:8];
        else if (Addr == 32'h0000007B)
            RDAR_reg = UID_reg[23:16];
        else if (Addr == 32'h0000007C)
            RDAR_reg = UID_reg[31:24];
        else if (Addr == 32'h0000007D)
            RDAR_reg = UID_reg[39:32];
        else if (Addr == 32'h0000007E)
            RDAR_reg = UID_reg[47:40];
        else if (Addr == 32'h0000007F)
            RDAR_reg = UID_reg[55:48];
        else if (Addr == 32'h00000080)
            RDAR_reg = UID_reg[63:56];
        else if (Addr == 32'h00800000)
            RDAR_reg = STR1V;
        else if (Addr == 32'h00800001)
            RDAR_reg = STR2V;
        else if (Addr == 32'h00800002)
            RDAR_reg = CFR1V;
        else if (Addr == 32'h00800003)
            RDAR_reg = CFR2V;
        else if (Addr == 32'h00800004)
            RDAR_reg = CFR3V;
        else if (Addr == 32'h00800005)
            RDAR_reg = CFR4V;
        else if (Addr == 32'h00800006)
            RDAR_reg = CFR5V;
        else if (Addr == 32'h00800008)
            RDAR_reg = ICEV;
        else if (Addr == 32'h00800067)
            RDAR_reg = INS0V;
        else if (Addr == 32'h00800068)
            RDAR_reg = INC0V;
		else if (Addr == 32'h00800069)
			RDAR_reg = INS1V;
        else if (Addr == 32'h00800089)
            RDAR_reg = ECSV;
        else if (Addr == 32'h0080008A)
            RDAR_reg = ECTV[7:0];
        else if (Addr == 32'h0080008B)
            RDAR_reg = ECTV[15:8];
        else if (Addr == 32'h0080008E)
            RDAR_reg = EATV[7:0];
        else if (Addr == 32'h0080008F)
            RDAR_reg = EATV[15:8];
        else if (Addr == 32'h00800040)
            RDAR_reg = EATV[23:16];
        else if (Addr == 32'h00800041)
            RDAR_reg = EATV[31:24];
        else if (Addr == 32'h00800091)
            RDAR_reg = SECV[7:0];
        else if (Addr == 32'h00800092)
            RDAR_reg = SECV[15:8];
        else if (Addr == 32'h00800093)
            RDAR_reg = SECV[23:16];
        else if (Addr == 32'h00800095)
            RDAR_reg = DCRV[7:0];
        else if (Addr == 32'h00800096)
            RDAR_reg = DCRV[15:8];
        else if (Addr == 32'h00800097)
            RDAR_reg = DCRV[23:16];
        else if (Addr == 32'h00800098)
            RDAR_reg = DCRV[31:24];
        else if (Addr == 32'h0080009B)
            RDAR_reg = PPLV;
        else
            RDAR_reg = 8'bXX;//N/A

    end
    endtask

    ///////////////////////////////////////////////////////////////////////////
    // edge controll processes
    ///////////////////////////////////////////////////////////////////////////

    always @(posedge PoweredUp)
    begin
        rising_edge_PoweredUp = 1;
        #1 rising_edge_PoweredUp = 0;
    end
	

    always @(posedge SCK_ipd)
    begin
       rising_edge_SCK_ipd = 1'b1;
       #1 rising_edge_SCK_ipd = 1'b0;
    end

    always @(negedge SCK_ipd)
    begin
       falling_edge_SCK_ipd = 1'b1;
       #1 falling_edge_SCK_ipd = 1'b0;
    end

    always @(posedge CSNeg_ipd)
    begin
        rising_edge_CSNeg_ipd = 1'b1;
        #1 rising_edge_CSNeg_ipd = 1'b0;
    end

    always @(negedge CSNeg_ipd)
    begin
        falling_edge_CSNeg_ipd = 1'b1;
        #1 falling_edge_CSNeg_ipd = 1'b0;
    end

    always @(negedge write or negedge write_new)
    begin
        falling_edge_write = 1;
        #1 falling_edge_write = 0;
    end

    always @(posedge reseted)
    begin
        rising_edge_reseted = 1;
        #1 rising_edge_reseted = 0;
    end

    always @(negedge RESETNeg)
    begin
        falling_edge_RESETNeg = 1;
        #1 falling_edge_RESETNeg = 0;
    end

    always @(posedge RESETNeg)
    begin
        rising_edge_RESETNeg = 1;
        #1 rising_edge_RESETNeg = 0;
    end

    always @(posedge PSTART)
    begin
        rising_edge_PSTART = 1'b1;
        #1 rising_edge_PSTART = 1'b0;
    end

    always @(posedge PDONE)
    begin
        rising_edge_PDONE = 1'b1;
        #1 rising_edge_PDONE = 1'b0;
    end

    always @(posedge WSTART)
    begin
        rising_edge_WSTART = 1;
        #1 rising_edge_WSTART = 0;
    end

    always @(posedge WDONE)
    begin
        rising_edge_WDONE = 1'b1;
        #1 rising_edge_WDONE = 1'b0;
    end

    always @(posedge CSDONE)
    begin
        rising_edge_CSDONE = 1'b1;
        #1 rising_edge_CSDONE = 1'b0;
    end

    always @(posedge EESSTART)
    begin
        rising_edge_EESSTART = 1;
        #1 rising_edge_EESSTART = 0;
    end

    always @(posedge EESDONE)
    begin
        rising_edge_EESDONE = 1'b1;
        #1 rising_edge_EESDONE = 1'b0;
    end

    always @(posedge bc_done)
    begin
        rising_edge_BCDONE = 1'b1;
        #1 rising_edge_BCDONE = 1'b0;
    end

    always @(posedge ESTART)
    begin
        rising_edge_ESTART = 1'b1;
        #1 rising_edge_ESTART = 1'b0;
    end

    always @(posedge EDONE)
    begin
        rising_edge_EDONE = 1'b1;
        #1 rising_edge_EDONE = 1'b0;
    end

    always @(posedge SEERC_START)
    begin
        rising_edge_SEERC_START = 1'b1;
        #1 rising_edge_SEERC_START = 1'b0;
    end

    always @(posedge SEERC_DONE)
    begin
        rising_edge_SEERC_DONE = 1'b1;
        #1 rising_edge_SEERC_DONE = 1'b0;
    end

    always @(posedge PRGSUSP_out)
    begin
        PRGSUSP_out_event = 1;
        #1 PRGSUSP_out_event = 0;
    end

    always @(posedge ERSSUSP_out)
    begin
        ERSSUSP_out_event = 1;
        #1 ERSSUSP_out_event = 0;
    end

    always @(posedge START_T1_in)
    begin
        rising_edge_START_T1_in = 1'b1;
        #1 rising_edge_START_T1_in = 1'b0;
    end

    always @(posedge CRCSTART)
    begin
        rising_edge_CRCSTART = 1'b1;
        #1 rising_edge_CRCSTART = 1'b0;
    end

    always @(posedge CRCDONE)
    begin
        rising_edge_CRCDONE = 1'b1;
        #1 rising_edge_CRCDONE = 1'b0;
    end

    always @(change_addr)
    begin
        change_addr_event = 1'b1;
        #1 change_addr_event = 1'b0;
    end
    
    always @(negedge RDYBSY)
    begin
        falling_edge_RDYBSY = 1;
        #1 falling_edge_RDYBSY = 0;
    end

    always @(current_state)
    begin
        current_state_event = 1'b1;
        #1 current_state_event = 1'b0;
    end

    always @(Instruct)
    begin
        Instruct_event = 1'b1;
        #1 Instruct_event = 1'b0;
    end

    always @(posedge DPD_out)
    begin
        rising_edge_DPD_out = 1'b1;
        #1 rising_edge_DPD_out = 1'b0;
    end

    always @(posedge RST_out)
    begin
        rising_edge_RST_out = 1'b1;
        #1 rising_edge_RST_out = 1'b0;
    end

    always @(negedge RST)
    begin
        falling_edge_RST = 1'b1;
        #1 falling_edge_RST = 1'b0;
    end

    always @(posedge SWRST_out)
    begin
        rising_edge_SWRST_out = 1'b1;
        #1 rising_edge_SWRST_out = 1'b0;
    end

    always @(negedge PASSULCK_in)
    begin
        falling_edge_PASSULCK_in = 1'b1;
        #1 falling_edge_PASSULCK_in = 1'b0;
    end

    always @(negedge PPBERASE_in)
    begin
        falling_edge_PPBERASE_in = 1'b1;
        #1 falling_edge_PPBERASE_in = 1'b0;
    end

    integer IOt_01;
    integer IOt_0Z;
    integer DSt_01;
    integer SEERCIOt;
    integer SEERCIOt_dly;

    reg  BuffInIO;
    wire BuffOutIO;

    reg  BuffInIOZ;
    wire BuffOutIOZ;

    reg  BuffInDS;
    wire BuffOutDS;

    reg  SEERCSInIO;
    wire SEERCOutIO;

    BUFFER    BUF_DOut   (BuffOutIO, BuffInIO);
    BUFFER    BUF_DOutZ  (BuffOutIOZ, BuffInIOZ);
    BUFFER    BUF_DS     (BuffOutDS, BuffInDS);
    BUFFER    BUF_SEERC  (SEERCOutIO, SEERCSInIO);

    initial
    begin
        BuffInIO   = 1'b1;
        BuffInIOZ  = 1'b1;
        BuffInDS   = 1'b1;
        SEERCSInIO = 1'b0;
    end

    always @(posedge BuffOutIO)
    begin
        IOt_01 = $time;
    end

    always @(posedge BuffOutIOZ)
    begin
        IOt_0Z = $time;
    end

    always @(posedge BuffOutDS)
    begin
        DSt_01 = $time;
    end

    // For SEECR time
    // Use always block to have some functionality in case user doesn't use SDF
    // Default delay will be #10
    always @(negedge SEERCOutIO)
    begin
        SEERCIOt      <= $time;
    end

    always @(SEERCIOt)
    begin
        SEERCIOt_dly  <= SEERCIOt;
    end

    always @(SEERCIOt_dly)
    begin
        if (SEERCIOt == 60e6)
            tdevice_SEERC = tdevice_SEERC_max;
        else if (SEERCIOt == 55e6)
            tdevice_SEERC = tdevice_SEERC_typ;
        else if (SEERCIOt == 55e6)
            tdevice_SEERC = tdevice_SEERC_min;
        else
            tdevice_SEERC = 60e6;
    end
    // end SEECR time

    always @(DataDriveOut_SO,DataDriveOut_SI,DataDriveOut_Dout)
    begin
        if ((IOt_01 > SCK_cycle/2) && DOUBLE)
        begin
            glitch = 1;
            SOut_zd        <= #(IOt_01-1000) DataDriveOut_SO;
            SIOut_zd       <= #(IOt_01-1000) DataDriveOut_SI;
            Dout_zd[3:2]   <= #(IOt_01-1000) DataDriveOut_Dout;
            Dout_zd[1]     <= #(IOt_01-1000) DataDriveOut_SO;
            Dout_zd[0]     <= #(IOt_01-1000) DataDriveOut_SI;
        end
        else
        begin
            glitch = 0;
            SOut_zd        <= DataDriveOut_SO;
            SIOut_zd       <= DataDriveOut_SI;
            Dout_zd[3:2]   <= DataDriveOut_Dout;
            Dout_zd[1]     <= DataDriveOut_SO;
            Dout_zd[0]     <= DataDriveOut_SI;
        end
    end

    always @(rising_edge_SCK_ipd, falling_edge_SCK_ipd)
    begin
        if (~CSNeg_ipd)
        begin
      // In DPD mode DS will not toggle during an attempted read transaction
            if (DPD_in == 1'b1)
            begin
                glitch_ds = 0;
                DS_zd  <= 1'b0;
            end
      // Detect glitch
            else if ((DSt_01 > SCK_cycle/2)  && DATA_STROBE)
            begin
                glitch_ds = 1;
                DS_zd  <= #DSt_01 DataDriveOut_DS;
            end
//       Read/Write transactions
            else if (DATA_STROBE)
            begin
                glitch_ds = 0;
                DS_zd  <=  #DSt_01 DataDriveOut_DS;
            end
        end
    end

endmodule

module BUFFER (OUT,IN);
    input IN;
    output OUT;
    buf   ( OUT, IN);
endmodule
module memory_features();
// ------------------------------------------------------------------------
// ----------------    start of memory management section    --------------
// ------------------------------------------------------------------------

    // memory partitioning parameters
    parameter list_num       = 128;
    parameter list_size      = 20'h40000;   //2^19+7=2^26, 256Mb=32MB=2^20+5
    // memory initial data value
    parameter MaxData        = 8'hFF;

    // memory management routines
    // handle dynamic memory allocation

    // abstract memory region model
    class linked_list_c;
        // memory element model
        reg[31:0] key_address;
        integer val_data;
        // organize memory storage elements into a linked list
        linked_list_c successor;

        function new(
            integer address_a,
            integer data_a);
        begin
            key_address = address_a;
            val_data = data_a;
            successor = null;
        end
        endfunction
    endclass

    // partition memory region for faster access
    linked_list_c linked_list [list_num];
    // class methods internal communication pool
    linked_list_c found;
    linked_list_c prev;
    linked_list_c sub_linked_list;
    linked_list_c sub_linked_list_last;

    // low-level routines
    class low_level_interface_c;

        // assure proper initialization
        function new;
            integer new_iter;
        begin
            // initialize linked list handles
            for(new_iter=0; new_iter < list_num; new_iter = new_iter + 1)
                linked_list[new_iter] = null;
            found = null;
            prev = null;
            sub_linked_list = null;
            sub_linked_list_last = null;
        end
        endfunction

        // Iterate through linked listed comapring key values
        // Stop when key value greater or equal
        task position_list(
            input integer address_a,
            input linked_list_c root);
        begin
            found = root;
            prev = null;
            while ((found != null) && (found.key_address < address_a))
            begin
                prev = found;
                found = found.successor;
            end
        end
        endtask

        // Add new element to a linked list
        task insert_list(
            input integer address_a,
            input integer data_a,
            input integer list_id);

            linked_list_c new_element;
        begin
            this.position_list(
                address_a,
                linked_list[list_id]);

            // Insert at list tail
            if (found == null)
            begin
                prev.successor = new(address_a, data_a);
            end
            else
            begin
                // Element exists, update memory data value
                if (found.key_address == address_a)
                begin
                    found.val_data = data_a;
                end
                else
                begin
                    // No element found, allocate and link
                    new_element = new(address_a, data_a);
                    new_element.successor = found;
                    // Possible root position
                    if (prev != null)
                    begin
                        prev.successor = new_element;
                    end
                    else
                    begin
                        linked_list[list_id] = new_element;
                    end
                end
            end
        end
        endtask

        // Remove element from a linked list
        task remove_list(
            input integer address_a,
            input integer list_id);

        begin
            this.position_list(
                address_a,
                linked_list[list_id]);

            if (found != null)
                // Key value match
                if (found.key_address == address_a)
                begin
                    // Handle root position removal
                    if (prev != null)
                        prev.successor = found.successor;
                    else
                        linked_list[list_id] = found.successor;
                    // garbage collector
                    found = null;
                end
        end
        endtask

        // Remove range of elements from a linked list
        // Higher performance than one-by-one removal
        task remove_list_range(
            input integer address_low,
            input integer address_high,
            input integer list_id);
            linked_list_c iter;
            linked_list_c prev_remove;
            linked_list_c link_element;
            integer flag_test;
        begin
            iter = linked_list[list_id];
            prev_remove = null;
            flag_test = 1;
            // Find first linked list element belonging to
            // a specified address range [address_low, address_high]
            if (iter != null)
                while (flag_test == 1)
                    if (iter == null)
                        flag_test = 0;
                    else if (!((iter.key_address >= address_low) &&
                    (iter.key_address <= address_high)))
                    begin
                        prev_remove = iter;
                        iter = iter.successor;
                    end
                    else
                        flag_test = 0;
            // Continue until address_high reached
            // Deallocate linked list elements pointed by iterator
            if (iter != null)
            begin
                while ((iter != null) &&
                (iter.key_address >= address_low) &&
                (iter.key_address <= address_high))
                begin
                    link_element = iter.successor;
                    //garbage collector
                    iter.successor = null;
                    iter = link_element;
                end
                // Handle possible root value change
                if ( prev_remove != null )
                    prev_remove.successor = link_element;
                else
                    linked_list[list_id] = link_element;
            end
        end
        endtask

    endclass

    // higher-level routines
    // provided memory RW operation class interface
    class rw_interface_c;

        low_level_interface_c low_level_interface;

        // assure proper initialization
        function new;
            integer new_iter;
        begin
            // allocate low level interface object
            low_level_interface = new;
        end
        endfunction

        task read_mem(
            inout integer data_a,
            input integer address_a);

            integer mem_data;
            integer list_id;
        begin
		     //$display("MODEL_VREAD: Address: 0x%h, Data: 0x%h @ time: %t\n", address_a, data_a, $time);
            // Higher performance, segment paritioning
            list_id = address_a / list_size;
            if (linked_list[list_id] == null)
                // Not allocated, not written, initial value
                mem_data = MaxData;
            else
            begin
                low_level_interface.position_list(
                    address_a,
                    linked_list[list_id]);
                if (found != null)
                begin
                    if (found.key_address == address_a)
                        // Allocated, val_data stored
                        mem_data = found.val_data;
                    else
                        // Not allocated, not written, initial value
                        mem_data = MaxData;
                end
                else
                begin
                    // Not allocated, not written, initial value
                    mem_data = MaxData;
                end
            end
            data_a = mem_data;
        end
        endtask

        // Memory WRITE operation performed above dynamically allocated space
        task write_mem(
            input integer address_a,
            input integer data_a);

            integer list_id;
        begin
		      //$display("MODEL_VWRITE: Address: 0x%h, Data: 0x%h @ time: %t\n", address_a, data_a, $time);
            // Higher performance, segment paritioning
            list_id = address_a / list_size;
            if (data_a !== MaxData)
            begin
                // Handle possible root value update
                if (linked_list[list_id] !== null)
                begin
                    low_level_interface.insert_list(
                        address_a,
                        data_a,
                        list_id);
                end
                else
                begin
                    linked_list[list_id] =
                    new(address_a, data_a);
                end
            end
            else
            begin
                // Deallocate if initial value written
                // No linked list, NOP, initial value implicit
                if (linked_list[list_id] !== null)
                begin
                    low_level_interface.remove_list(
                        address_a,
                        list_id);
                end
            end
        end
        endtask

        // Address range to be erased
        task erase_mem(
            input integer address_low,
            input integer address_high);

            integer list_id;
        begin
            list_id = address_low / list_size;

            low_level_interface.remove_list_range(
                address_low,
                address_high,
                list_id
                );
        end
        endtask

    endclass

    // object declaration holding memory management model
    rw_interface_c rw_interface;

    //interface towards higher hierarchy instances routine calls
    //wrapped from within the memory_features module
    //low-level routine access forbidden
    task initialize_w;
    begin
        rw_interface = new;
    end
    endtask

    task read_mem_w(
        inout integer data_a,
        input integer address_a);
    begin
        rw_interface.read_mem(data_a, address_a);
    end
    endtask

    task write_mem_w(
        input integer address_a,
        input integer data_a);
    begin
        rw_interface.write_mem(address_a, data_a);
    end
    endtask

    task erase_mem_w(
        input integer address_low,
        input integer address_high);
    begin
        rw_interface.erase_mem(address_low, address_high);
    end
    endtask
endmodule


