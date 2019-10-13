module STI_DAC(clk ,reset, load, pi_data, pi_length, pi_fill, pi_msb, pi_low, pi_end,
	       so_data, so_valid,
	       oem_finish, oem_dataout, oem_addr,
	       odd1_wr, odd2_wr, odd3_wr, odd4_wr, even1_wr, even2_wr, even3_wr, even4_wr);

input		clk, reset;
input		load, pi_msb, pi_low, pi_end; 
input	[15:0]	pi_data;
input	[1:0]	pi_length;
input		pi_fill;
output		so_data, so_valid;

output  oem_finish, odd1_wr, odd2_wr, odd3_wr, odd4_wr, even1_wr, even2_wr, even3_wr, even4_wr;
output [4:0] oem_addr;
output [7:0] oem_dataout;

//==============================================================================

//////////////////////////////////
//          STI reg wire        //
//////////////////////////////////
reg		pi_msb_reg;
reg		pi_low_reg;
reg		pi_fill_reg;
reg	[1:0]	pi_length_reg;
reg	[15:0]	pi_data_reg;
reg [4:0]	ptr;
reg [1:0]	sti_c_st, sti_n_st;

reg  [31:0] data_bus;
reg  [4:0]  msb_bit;
wire [4:0]  ptr_start, ptr_end;

//////////////////////////////////
//          DAC reg wire        //
//////////////////////////////////
reg [7:0] oem_dataout;
reg [1:0] dac_c_st, dac_n_st;
reg [2:0] count_data;
reg [8:0] count_oem;

//////////////////////////////////
//          STI design          //
//////////////////////////////////
parameter idle = 2'b00;
parameter pi_catch = 2'b01;
parameter out = 2'b11;
parameter done = 2'b10;

always@(posedge clk or posedge reset)
  if(reset==1)
	begin
  	pi_msb_reg <= 0;
	pi_low_reg <= 0;
	pi_fill_reg <= 0;
	pi_length_reg <= 0;
	pi_data_reg <= 0;
	end
  else if(load && !pi_end)
	begin
  	pi_msb_reg <= pi_msb;
	pi_low_reg <= pi_low;
	pi_fill_reg <= pi_fill;
	pi_length_reg <= pi_length;
	pi_data_reg <= pi_data;
	end

always@(*)
  if(pi_length_reg[1] && pi_fill_reg)
	data_bus = (pi_length_reg[0]) ? {pi_data_reg, 16'd0} : {8'd0, pi_data_reg, 8'd0};
  else if((!pi_length_reg) && pi_low_reg)
		  data_bus = {24'd0, pi_data_reg[15:8]};
	   else
		  data_bus = {16'd0, pi_data_reg};
/* always@(*)
  case(pi_length_reg)
	2'b00 	: data_bus = (pi_low_reg) ? {24'd0, pi_data_reg[15:8]} : {16'd0, pi_data_reg};
	2'b01 	: data_bus = {16'd0, pi_data_reg};
	2'b10	: data_bus = (pi_fill_reg) ? {8'd0, pi_data_reg, 8'd0} : {16'd0, pi_data_reg};	
	2'b11	: data_bus = (pi_fill_reg) ? {pi_data_reg, 16'd0} : {16'd0, pi_data_reg}; 
  endcase*/
always@(*)
 case(pi_length_reg)
    2'b00 : msb_bit = 5'd7;		
    2'b01 : msb_bit = 5'd15;
	2'b10 : msb_bit = 5'd23;
    2'b11 : msb_bit = 5'd31;
 endcase

assign ptr_start = (pi_msb_reg) ? msb_bit : 5'd0; 
assign ptr_end = (pi_msb_reg) ? 5'd0 : msb_bit; 

always@(posedge clk or posedge reset)
 if(reset)
    sti_c_st <= idle;
 else
    sti_c_st <= sti_n_st;

always@(*)
 case(sti_c_st)
	idle 	: sti_n_st = (load)? pi_catch : (pi_end)? done : idle;
	pi_catch: sti_n_st = out;
	out		: sti_n_st = (ptr == ptr_end)? idle : out;
	done	: sti_n_st = done;
	default	: sti_n_st = idle;
 endcase

always@(posedge clk)
 if(sti_c_st == pi_catch)
  ptr <= ptr_start;
  else if (pi_msb_reg)
		ptr <= ptr - 1;
       else 
		ptr <= ptr+1;
		
 assign so_data = (sti_c_st == done) ? 0 : data_bus[ptr];
 assign so_valid = (sti_c_st == out) || (sti_c_st == done); 
	
//////////////////////////////////
//          DAC design          //
//////////////////////////////////
parameter wr_idle = 2'b00;
parameter wr_odd  = 2'b01;
parameter wr_even = 2'b10;

always@(posedge clk or posedge reset)
  if(reset)
	count_data <= 3'd7;
  else if(so_valid)
		count_data <= count_data - 1;		
always@(posedge clk)
  if(so_valid)
	oem_dataout[count_data] <= so_data;
	
always@(posedge clk or posedge reset)
  if(reset)
	count_oem <= 9'd0;
  else if(dac_c_st != wr_idle)
		count_oem <= count_oem +1;
		
		
always@(posedge clk or posedge reset)
  if(reset)
	dac_c_st <= wr_idle;
  else
	dac_c_st <= dac_n_st;	
always@(*)
  if(dac_c_st == wr_idle )
	dac_n_st = (count_data!=3'd0) ? wr_idle : (count_oem[3] == count_oem[0]) ?  wr_odd : wr_even; 
  else
    dac_n_st =  wr_idle ;
 
assign oem_addr = count_oem[5:1]; 

assign odd1_wr = (dac_c_st == wr_odd) & (count_oem[7:6] == 2'b00);
assign odd2_wr = (dac_c_st == wr_odd) & (count_oem[7:6] == 2'b01);
assign odd3_wr = (dac_c_st == wr_odd) & (count_oem[7:6] == 2'b10);
assign odd4_wr = (dac_c_st == wr_odd) & (count_oem[7:6] == 2'b11);
assign even1_wr = (dac_c_st == wr_even) & (count_oem[7:6] == 2'b00);
assign even2_wr = (dac_c_st == wr_even) & (count_oem[7:6] == 2'b01);
assign even3_wr = (dac_c_st == wr_even) & (count_oem[7:6] == 2'b10);
assign even4_wr = (dac_c_st == wr_even) & (count_oem[7:6] == 2'b11);

assign oem_finish = count_oem[8]; 

	
endmodule
	