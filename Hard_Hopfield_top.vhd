library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity Hard_Hopfield_top is
   generic (N:natural range 1 to 16:=5);
    Port (
			CLK50_in : in  STD_LOGIC;
         key: in  STD_LOGIC_VECTOR(1 downto 0);
         led: out  STD_LOGIC_VECTOR(1 downto 0);

         OV7670_SIOC  : out   STD_LOGIC;
         OV7670_SIOD  : inout STD_LOGIC;
         OV7670_RESET : out   STD_LOGIC;
         OV7670_PWDN  : out   STD_LOGIC;
         OV7670_VSYNC : in    STD_LOGIC;
         OV7670_HREF  : in    STD_LOGIC;
         OV7670_PCLK  : in    STD_LOGIC;
         OV7670_XCLK  : out   STD_LOGIC;
         OV7670_D     : in    STD_LOGIC_VECTOR(7 downto 0);

			AN430_dclk : out  STD_LOGIC;
			AN430_red  : out  STD_LOGIC_VECTOR (7 downto 0);
         AN430_green: out  STD_LOGIC_VECTOR (7 downto 0);
         AN430_blue : out  STD_LOGIC_VECTOR (7 downto 0);
         AN430_de   : out  STD_LOGIC
		);
end Hard_Hopfield_top;

architecture XC7K325T of Hard_Hopfield_top is
component RAM_2NxM is
    generic (N:natural range 1 to 16:=0; M:natural range 1 to 32:=8);
    port (CLKA : in std_logic;
          WEA  : in std_logic_vector(0 downto 0);
          ADDRA: in std_logic_vector(N-1 downto 0);
          DINA : in std_logic_vector(M-1 downto 0);
          ADDRB: in std_logic_vector(N-1 downto 0);
          DOUTB: out std_logic_vector(M-1 downto 0)
    );
end component;

component RAM_2NxM_2clk is
    generic (N:natural range 1 to 32:=0; M:natural range 1 to 32:=8);
    port (CLKA : in std_logic;
          WEA  : in std_logic_vector(0 downto 0);
          ADDRA: in std_logic_vector(N-1 downto 0);
          DINA : in std_logic_vector(M-1 downto 0);
          CLKB : in std_logic;
          ADDRB: in std_logic_vector(N-1 downto 0);
          DOUTB: out std_logic_vector(M-1 downto 0)
    );
end component;

component RAM_2NxM_2out is
    generic (N:natural range 1 to 16:=0; M:natural range 1 to 32:=8);
    port (CLK : in std_logic;
          WE  : in std_logic_vector(0 downto 0);
          ADDR: in std_logic_vector(N-1 downto 0);
          DIN : in std_logic_vector(M-1 downto 0);
          ADDR1: in std_logic_vector(N-1 downto 0);
          DOUT1: out std_logic_vector(M-1 downto 0);
          ADDR2: in std_logic_vector(N-1 downto 0);
          DOUT2: out std_logic_vector(M-1 downto 0)
    );
end component;

component clk_core is
	port (
	CLK50_IN: in std_logic;
	CLK100: out std_logic;
	CLK25: out std_logic;
	CLK8: out std_logic
	);
end component;
signal clk100,clk25,clk8:std_logic;

component freq_div_module is
    Port ( 
		clk   : in  STD_LOGIC;
      value : in  STD_LOGIC_VECTOR(31 downto 0);
      result: out STD_LOGIC
	 );
end component;
signal clk_10Khz: std_logic:='0';

component keys_supervisor is
   Port ( 
      clk : in std_logic;
      key : in std_logic_vector(1 downto 0);
      key0: out std_logic;
      key1: out std_logic;
      reset_signal: out std_logic;
      value  : out std_logic_vector(2 downto 0)
	);
end component;
signal key0: std_logic:='0';
signal key1: std_logic:='0';
signal reset_signal: std_logic:='0';
signal pattern_idx: std_logic_vector(2 downto 0):=(others=>'0');

component LCD_AN430 is
    Port ( lcd_clk   : in std_logic;
           lcd_r_out : out  STD_LOGIC_VECTOR (7 downto 0);
           lcd_g_out : out  STD_LOGIC_VECTOR (7 downto 0);
           lcd_b_out : out  STD_LOGIC_VECTOR (7 downto 0);
           lcd_de    : out  STD_LOGIC;
			  clk_wr: in std_logic;
           x : in  STD_LOGIC_VECTOR (9 downto 0);
           y : in  STD_LOGIC_VECTOR (9 downto 0);
			  pixel : in std_logic_vector(7 downto 0)
    );
end component;
signal lcd_clk: std_logic;
signal lcd_de: std_logic:='0';
signal lcd_pixel: STD_LOGIC_VECTOR (7 downto 0):=(others=>'0');
signal lcd_x: STD_LOGIC_VECTOR (9 downto 0):=(others=>'0');
signal lcd_y: STD_LOGIC_VECTOR (9 downto 0):=(others=>'0');
signal lcd_flag: std_logic:='0';
	
component CAM_OV7670 is
    Port (
      clk   : in std_logic;
      vsync : in std_logic;
		href  : in std_logic;
		din   : in std_logic_vector(7 downto 0);
      x : out std_logic_vector(9 downto 0);
      y : out std_logic_vector(9 downto 0);
      pixel : out std_logic_vector(7 downto 0);
      ready : out std_logic
		);
end component;
signal cam_ready    : std_logic;
signal cam_clk      : std_logic;
signal cam_pixel    : std_logic_vector(7 downto 0):=(others=>'0');
signal cam_x        : std_logic_vector(9 downto 0):=(others=>'0');
signal cam_y        : std_logic_vector(9 downto 0):=(others=>'0');

COMPONENT image_2Nx2N_scale_down is
   Generic (N:natural range 1 to 16:=5;
            K:natural range 1 to 16:=3);
   Port ( 
		clk      : in std_logic;
      addr_in  : out std_logic_vector(2*N+2*K-1 downto 0);
      pixel_in : in std_logic_vector(7 downto 0);
      addr_out : out std_logic_vector(2*N-1 downto 0);
      pixel_out: out std_logic_vector(7 downto 0)
	);
END COMPONENT;
signal cambuffer_rd_addr1: std_logic_vector(15 downto 0):=(others=>'0');
signal cambuffer_rd_pixel1: std_logic_vector(7 downto 0):=(others=>'0');
signal patterns_down_wr_addr: std_logic_vector(11 downto 0):=(others=>'0');
signal patterns_down_wr_pixel: std_logic_vector(7 downto 0):=(others=>'0');
signal patterns_reload: std_logic:='0';

signal cambuffer_rd_addr2: std_logic_vector(15 downto 0):=(others=>'0');
signal cambuffer_rd_pixel2: std_logic_vector(7 downto 0):=(others=>'0');
signal image_down_wr_addr: std_logic_vector(2*N-1 downto 0):=(others=>'0');
signal image_down_wr_pixel: std_logic_vector(7 downto 0):=(others=>'0');

signal pattern_learn_cwr: std_logic:='0';
signal pattern_forget_cwr: std_logic:='0';
signal pattern_rd_addr: std_logic_vector(11 downto 0):=(others=>'0');
signal pattern_rd_pixel: std_logic_vector(7 downto 0):=(others=>'0');
signal pattern_wr_addr: std_logic_vector(2*N-1 downto 0):=(others=>'0');
signal pattern_wr_pixel: std_logic_vector(7 downto 0):=(others=>'0');

signal pattern_learn_pixel: std_logic_vector(7 downto 0):=(others=>'0');
signal pattern_forget_pixel: std_logic_vector(7 downto 0):=(others=>'0');
signal image_pixel: std_logic_vector(7 downto 0):=(others=>'0');

signal pattern0_flag: std_logic:='0';
signal pattern0_data: std_logic_vector(7 downto 0):=(others=>'0');
signal pattern0_x,pattern0_y:std_logic_vector(9 downto 0):=(others=>'0');
signal pattern0_pixel: std_logic_vector(7 downto 0):=(others=>'0');
signal pattern0_cwr: std_logic:='0';

signal pattern1_flag: std_logic:='0';
signal pattern1_data: std_logic_vector(7 downto 0):=(others=>'0');
signal pattern1_x,pattern1_y:std_logic_vector(9 downto 0):=(others=>'0');
signal pattern1_pixel: std_logic_vector(7 downto 0):=(others=>'0');
signal pattern1_cwr: std_logic:='0';

signal pattern2_flag: std_logic:='0';
signal pattern2_data: std_logic_vector(7 downto 0):=(others=>'0');
signal pattern2_x,pattern2_y:std_logic_vector(9 downto 0):=(others=>'0');
signal pattern2_pixel: std_logic_vector(7 downto 0):=(others=>'0');
signal pattern2_cwr: std_logic:='0';

signal pattern3_flag: std_logic:='0';
signal pattern3_data: std_logic_vector(7 downto 0):=(others=>'0');
signal pattern3_x,pattern3_y:std_logic_vector(9 downto 0):=(others=>'0');
signal pattern3_pixel: std_logic_vector(7 downto 0):=(others=>'0');
signal pattern3_cwr: std_logic:='0';

signal pattern4_flag: std_logic:='0';
signal pattern4_data: std_logic_vector(7 downto 0):=(others=>'0');
signal pattern4_x,pattern4_y:std_logic_vector(9 downto 0):=(others=>'0');
signal pattern4_pixel: std_logic_vector(7 downto 0):=(others=>'0');
signal pattern4_cwr: std_logic:='0';

signal pattern5_flag: std_logic:='0';
signal pattern5_data: std_logic_vector(7 downto 0):=(others=>'0');
signal pattern5_x,pattern5_y:std_logic_vector(9 downto 0):=(others=>'0');
signal pattern5_pixel: std_logic_vector(7 downto 0):=(others=>'0');
signal pattern5_cwr: std_logic:='0';

signal pattern6_flag: std_logic:='0';
signal pattern6_data: std_logic_vector(7 downto 0):=(others=>'0');
signal pattern6_x,pattern6_y:std_logic_vector(9 downto 0):=(others=>'0');
signal pattern6_pixel: std_logic_vector(7 downto 0):=(others=>'0');
signal pattern6_cwr: std_logic:='0';

signal pattern7_flag: std_logic:='0';
signal pattern7_data: std_logic_vector(7 downto 0):=(others=>'0');
signal pattern7_x,pattern7_y:std_logic_vector(9 downto 0):=(others=>'0');
signal pattern7_pixel: std_logic_vector(7 downto 0):=(others=>'0');
signal pattern7_cwr: std_logic:='0';

COMPONENT image_2Nx2N_scale_up is
   Generic (N:natural range 1 to 16:=5;
            K:natural range 1 to 16:=3);
    Port ( 
		clk     : in std_logic;
      addr_in : out std_logic_vector(2*N-1 downto 0);
      pixel_in: in std_logic_vector(7 downto 0);
      addr_out: out std_logic_vector(2*N+2*K-1 downto 0);
      pixel_out: out std_logic_vector(7 downto 0)
	 );
END COMPONENT;
signal buffer_flag: std_logic:='0';
signal buffer_pixel: std_logic_vector(7 downto 0):=(others=>'0');
signal buffer_x,buffer_y:std_logic_vector(9 downto 0):=(others=>'0');
signal buffer_img_out_wr_addr: std_logic_vector(15 downto 0):=(others=>'0');
signal buffer_img_out_wr_pixel: std_logic_vector(7 downto 0):=(others=>'0');

component neural_hopfield_cpu is
   generic (N:natural range 1 to 16:=8);
    Port ( 
		clk       : in std_logic;
      reset     : in std_logic;
      reload    : in std_logic;
      learn     : in std_logic;
      forget    : in std_logic;
      data_in_addr: in std_logic_vector(N-1 downto 0);
      data_in  : in std_logic_vector(7 downto 0);
      data_out_addr: in std_logic_vector(N-1 downto 0);
      data_out : out std_logic_vector(7 downto 0);
      trained   : out std_logic
	 );
end component;
signal cpu_clk:std_logic;
signal cpu_data_in_addr: std_logic_vector(2*N-1 downto 0):=(others=>'0');
signal cpu_data_in: std_logic_vector(7 downto 0):=(others=>'0');
signal cpu_data_out_addr: std_logic_vector(2*N-1 downto 0):=(others=>'0');
signal cpu_data_out: std_logic_vector(7 downto 0):=(others=>'0');
signal cpu_reload: std_logic:='0';
signal cpu_learn: std_logic:='0';
signal cpu_forget: std_logic:='0';
signal cpu_trained: std_logic:='0';

signal interface_flag: std_logic:='0';
signal learn_touch: std_logic_vector(7 downto 0):=(others=>'0');

begin
clk_chip : clk_core port map (CLK50_in,CLK100,CLK25,CLK8);
lcd_clk<=clk8;
cam_clk<=clk25;
cpu_clk<=clk100;
-----------------------------------------------------

led<=key;
freq_10Khz_chip: freq_div_module port map(clk8,conv_std_logic_vector(400,32),clk_10Khz);
keys_chip: keys_supervisor port map
      (clk_10Khz,key,key0,key1,reset_signal,pattern_idx);

-----------------------------------------------------
OV7670_PWDN  <= '0'; --0 - power on
OV7670_RESET <= '1'; --0 - activate reset
OV7670_XCLK  <= cam_clk;
OV7670_siod  <= 'Z';
OV7670_sioc  <= '0';

OV7670_cam: CAM_OV7670 PORT MAP(
		clk   => OV7670_PCLK,
		vsync => OV7670_VSYNC,
		href  => OV7670_HREF,
		din   => OV7670_D,
      x =>cam_x,
      y =>cam_y,
      pixel =>cam_pixel,
      ready =>cam_ready
      );
-----------------------------------------------------  

AN430_dclk<=not(lcd_clk);
AN430_de<=lcd_de;
AN430_lcd: LCD_AN430 port map (
		lcd_clk,AN430_red,AN430_green,AN430_blue,lcd_de,
      cam_clk,lcd_x,lcd_y,lcd_pixel);

-----------------------------------------------------
process (cam_clk)
variable tmp: std_logic_vector(9 downto 0):=(others=>'0');
begin
   if rising_edge(cam_clk) then
      -----------------------------------------------------
      if (cam_ready='1')and(cam_x>=80)and(cam_x<560)and(cam_y>=104)and(cam_y<376) then
         lcd_x<=cam_x-conv_std_logic_vector(80,10);
         lcd_y<=cam_y-conv_std_logic_vector(104,10);
         lcd_flag<='1';
      else lcd_flag<='0';
      end if;
      -----------------------------------------------------
      if (lcd_x>=16)and(lcd_x<272)and(lcd_y>=8)and(lcd_y<264) then
         buffer_x<=lcd_x-conv_std_logic_vector(16,10);
         buffer_y<=lcd_y-conv_std_logic_vector(8,10);
         buffer_flag<='1';
      else buffer_flag<='0';
      end if;
      -----------------------------------------------------
      if (lcd_x>=312)and(lcd_x<376)and(lcd_y>=2)and(lcd_y<66) then
         pattern0_x<=lcd_x-conv_std_logic_vector(312,10);
         pattern0_y<=lcd_y-conv_std_logic_vector(2,10);
         pattern0_flag<='1';
      else pattern0_flag<='0';
      end if;
      -----------------------------------------------------
      if (lcd_x>=312)and(lcd_x<376)and(lcd_y>=70)and(lcd_y<134) then
         pattern1_x<=lcd_x-conv_std_logic_vector(312,10);
         pattern1_y<=lcd_y-conv_std_logic_vector(70,10);
         pattern1_flag<='1';
      else pattern1_flag<='0';
      end if;
      -----------------------------------------------------
      if (lcd_x>=312)and(lcd_x<376)and(lcd_y>=138)and(lcd_y<202) then
         pattern2_x<=lcd_x-conv_std_logic_vector(312,10);
         pattern2_y<=lcd_y-conv_std_logic_vector(138,10);
         pattern2_flag<='1';
      else pattern2_flag<='0';
      end if;
      -----------------------------------------------------
      if (lcd_x>=312)and(lcd_x<376)and(lcd_y>=206)and(lcd_y<270) then
         pattern3_x<=lcd_x-conv_std_logic_vector(312,10);
         pattern3_y<=lcd_y-conv_std_logic_vector(206,10);
         pattern3_flag<='1';
      else pattern3_flag<='0';
      end if;
      -----------------------------------------------------
      if (lcd_x>=400)and(lcd_x<464)and(lcd_y>=2)and(lcd_y<66) then
         pattern4_x<=lcd_x-conv_std_logic_vector(400,10);
         pattern4_y<=lcd_y-conv_std_logic_vector(2,10);
         pattern4_flag<='1';
      else pattern4_flag<='0';
      end if;
      -----------------------------------------------------
      if (lcd_x>=400)and(lcd_x<464)and(lcd_y>=70)and(lcd_y<134) then
         pattern5_x<=lcd_x-conv_std_logic_vector(400,10);
         pattern5_y<=lcd_y-conv_std_logic_vector(70,10);
         pattern5_flag<='1';
      else pattern5_flag<='0';
      end if;
      -----------------------------------------------------
      if (lcd_x>=400)and(lcd_x<464)and(lcd_y>=138)and(lcd_y<202) then
         pattern6_x<=lcd_x-conv_std_logic_vector(400,10);
         pattern6_y<=lcd_y-conv_std_logic_vector(138,10);
         pattern6_flag<='1';
      else pattern6_flag<='0';
      end if;
      -----------------------------------------------------
      if (lcd_x>=400)and(lcd_x<464)and(lcd_y>=206)and(lcd_y<270) then
         pattern7_x<=lcd_x-conv_std_logic_vector(400,10);
         pattern7_y<=lcd_y-conv_std_logic_vector(206,10);
         pattern7_flag<='1';
      else pattern7_flag<='0';
      end if;
      -----------------------------------------------------
      if
   --buffer frame
   ((lcd_x>=16)and(lcd_x<=272)and((lcd_y=8)or(lcd_y=264))) or
   (((lcd_x=16)or(lcd_x=272))and(lcd_y>=8)and(lcd_y<=264)) or
   --pattern0 frame
   ((lcd_x>=312)and(lcd_x<=376)and((lcd_y=2)or(lcd_y=66))) or
   (((lcd_x=312)or(lcd_x=376))and(lcd_y>=2)and(lcd_y<=66)) or
   --pattern1 frame
   ((lcd_x>=312)and(lcd_x<=376)and((lcd_y=70)or(lcd_y=134))) or
   (((lcd_x=312)or(lcd_x=376))and(lcd_y>=70)and(lcd_y<=134)) or
   --pattern2 frame
   ((lcd_x>=312)and(lcd_x<=376)and((lcd_y=138)or(lcd_y=202))) or
   (((lcd_x=312)or(lcd_x=376))and(lcd_y>=138)and(lcd_y<=202)) or
   --pattern3 frame
   ((lcd_x>=312)and(lcd_x<=376)and((lcd_y=206)or(lcd_y=270))) or
   (((lcd_x=312)or(lcd_x=376))and(lcd_y>=206)and(lcd_y<=270)) or
   --pattern4 frame
   ((lcd_x>=400)and(lcd_x<=464)and((lcd_y=2)or(lcd_y=66))) or
   (((lcd_x=400)or(lcd_x=464))and(lcd_y>=2)and(lcd_y<=66)) or
   --pattern5 frame
   ((lcd_x>=400)and(lcd_x<=464)and((lcd_y=70)or(lcd_y=134))) or
   (((lcd_x=400)or(lcd_x=464))and(lcd_y>=70)and(lcd_y<=134)) or
   --pattern6 frame
   ((lcd_x>=400)and(lcd_x<=464)and((lcd_y=138)or(lcd_y=202))) or
   (((lcd_x=400)or(lcd_x=464))and(lcd_y>=138)and(lcd_y<=202)) or
   --pattern7 frame
   ((lcd_x>=400)and(lcd_x<=464)and((lcd_y=206)or(lcd_y=270))) or
   (((lcd_x=400)or(lcd_x=464))and(lcd_y>=206)and(lcd_y<=270)) or
   
   --pattern0 selector
   ((pattern_idx="000") and (lcd_x>=300)and(lcd_x<=310)and(lcd_y>=2)and(lcd_y<=66)) or
   --pattern1 selector
   ((pattern_idx="001") and (lcd_x>=300)and(lcd_x<=310)and(lcd_y>=70)and(lcd_y<=134)) or
   --pattern2 selector
   ((pattern_idx="010") and (lcd_x>=300)and(lcd_x<=310)and(lcd_y>=138)and(lcd_y<=202)) or
   --pattern3 selector
   ((pattern_idx="011") and (lcd_x>=300)and(lcd_x<=310)and(lcd_y>=206)and(lcd_y<=270)) or
   --pattern4 selector
   ((pattern_idx="100") and (lcd_x>=388)and(lcd_x<=398)and(lcd_y>=2)and(lcd_y<=66)) or
   --pattern5 selector
   ((pattern_idx="101") and (lcd_x>=388)and(lcd_x<=398)and(lcd_y>=70)and(lcd_y<=134)) or
   --pattern6 selector
   ((pattern_idx="110") and (lcd_x>=388)and(lcd_x<=398)and(lcd_y>=138)and(lcd_y<=202)) or
   --pattern7 selector
   ((pattern_idx="111") and (lcd_x>=388)and(lcd_x<=398)and(lcd_y>=206)and(lcd_y<=270))
      then interface_flag<='1';
      else interface_flag<='0';
      end if;
      
      -----------------------------------------------------
      if interface_flag='1' then lcd_pixel<=(others=>'1');
      elsif buffer_flag='1' then 
         tmp:=("00"&buffer_pixel)+("00"&cam_pixel);
         lcd_pixel<=tmp(8 downto 1);
      elsif pattern0_flag='1' then lcd_pixel<=pattern0_pixel;
      elsif pattern1_flag='1' then lcd_pixel<=pattern1_pixel;
      elsif pattern2_flag='1' then lcd_pixel<=pattern2_pixel;
      elsif pattern3_flag='1' then lcd_pixel<=pattern3_pixel;
      elsif pattern4_flag='1' then lcd_pixel<=pattern4_pixel;
      elsif pattern5_flag='1' then lcd_pixel<=pattern5_pixel;
      elsif pattern6_flag='1' then lcd_pixel<=pattern6_pixel;
      elsif pattern7_flag='1' then lcd_pixel<=pattern7_pixel;
      elsif lcd_flag='1' then lcd_pixel<=cam_pixel;
      else lcd_pixel<=(others=>'0');
      end if;
      -----------------------------------------------------
   end if;
end process;
-----------------------------------------------------

cambuffer_RAM : RAM_2NxM_2out
  GENERIC MAP (16,8)
  PORT MAP (
    clk => cam_clk,
    we  => (0=>buffer_flag),
    addr => buffer_y(7 downto 0) & buffer_x(7 downto 0),
    din  => cam_pixel,
    addr1 => cambuffer_rd_addr1,
    dout1 => cambuffer_rd_pixel1,
    addr2 => cambuffer_rd_addr2,
    dout2 => cambuffer_rd_pixel2
  );

patterns_down_chip: image_2Nx2N_scale_down
    Generic map(6,2)
    Port map( 
      clk => cam_clk,
      addr_in   => cambuffer_rd_addr1,
      pixel_in  => cambuffer_rd_pixel1,
      addr_out  => patterns_down_wr_addr,
      pixel_out => patterns_down_wr_pixel
    );

pattern0_cwr<='1' when (pattern_idx="000")and(patterns_reload='1') else '0';
pattern0_RAM : RAM_2NxM_2out GENERIC MAP (12,8)
  PORT MAP (cam_clk,(0=>pattern0_cwr or reset_signal),
    patterns_down_wr_addr, patterns_down_wr_pixel and (7 downto 0=>not(reset_signal)),
    pattern0_y(5 downto 0) & pattern0_x(5 downto 0), pattern0_pixel,
    pattern_rd_addr, pattern0_data
  );

pattern1_cwr<='1' when (pattern_idx="001")and(patterns_reload='1') else '0';
pattern1_RAM : RAM_2NxM_2out GENERIC MAP (12,8)
  PORT MAP (cam_clk,(0=>pattern1_cwr or reset_signal),
    patterns_down_wr_addr, patterns_down_wr_pixel and (7 downto 0=>not(reset_signal)),
    pattern1_y(5 downto 0) & pattern1_x(5 downto 0), pattern1_pixel,
    pattern_rd_addr, pattern1_data
  );
  
pattern2_cwr<='1' when (pattern_idx="010")and(patterns_reload='1') else '0';
pattern2_RAM : RAM_2NxM_2out GENERIC MAP (12,8)
  PORT MAP (cam_clk,(0=>pattern2_cwr or reset_signal),
    patterns_down_wr_addr, patterns_down_wr_pixel and (7 downto 0=>not(reset_signal)),
    pattern2_y(5 downto 0) & pattern2_x(5 downto 0), pattern2_pixel,
    pattern_rd_addr, pattern2_data
  );

pattern3_cwr<='1' when (pattern_idx="011")and(patterns_reload='1') else '0';
pattern3_RAM : RAM_2NxM_2out GENERIC MAP (12,8)
  PORT MAP (cam_clk,(0=>pattern3_cwr or reset_signal),
    patterns_down_wr_addr, patterns_down_wr_pixel and (7 downto 0=>not(reset_signal)),
    pattern3_y(5 downto 0) & pattern3_x(5 downto 0), pattern3_pixel,
    pattern_rd_addr, pattern3_data
  );

pattern4_cwr<='1' when (pattern_idx="100")and(patterns_reload='1') else '0';
pattern4_RAM : RAM_2NxM_2out GENERIC MAP (12,8)
  PORT MAP (cam_clk,(0=>pattern4_cwr or reset_signal),
    patterns_down_wr_addr, patterns_down_wr_pixel and (7 downto 0=>not(reset_signal)),
    pattern4_y(5 downto 0) & pattern4_x(5 downto 0), pattern4_pixel,
    pattern_rd_addr, pattern4_data
  );
  
pattern5_cwr<='1' when (pattern_idx="101")and(patterns_reload='1') else '0';
pattern5_RAM : RAM_2NxM_2out GENERIC MAP (12,8)
  PORT MAP (cam_clk,(0=>pattern5_cwr or reset_signal),
    patterns_down_wr_addr, patterns_down_wr_pixel and (7 downto 0=>not(reset_signal)),
    pattern5_y(5 downto 0) & pattern5_x(5 downto 0), pattern5_pixel,
    pattern_rd_addr, pattern5_data
  );

pattern6_cwr<='1' when (pattern_idx="110")and(patterns_reload='1') else '0';
pattern6_RAM : RAM_2NxM_2out GENERIC MAP (12,8)
  PORT MAP (cam_clk,(0=>pattern6_cwr or reset_signal),
    patterns_down_wr_addr, patterns_down_wr_pixel and (7 downto 0=>not(reset_signal)),
    pattern6_y(5 downto 0) & pattern6_x(5 downto 0), pattern6_pixel,
    pattern_rd_addr, pattern6_data
  );

pattern7_cwr<='1' when (pattern_idx="111")and(patterns_reload='1') else '0';
pattern7_RAM : RAM_2NxM_2out GENERIC MAP (12,8)
  PORT MAP (cam_clk,(0=>pattern7_cwr or reset_signal),
    patterns_down_wr_addr, patterns_down_wr_pixel and (7 downto 0=>not(reset_signal)),
    pattern7_y(5 downto 0) & pattern7_x(5 downto 0), pattern7_pixel,
    pattern_rd_addr, pattern7_data
  );

-----------------------------------------------------
with pattern_idx select
   pattern_rd_pixel<=pattern0_data when "000",
                     pattern1_data when "001",
                     pattern2_data when "010",
                     pattern3_data when "011",
                     pattern4_data when "100",
                     pattern5_data when "101",
                     pattern6_data when "110",
                     pattern7_data when "111",
                     (others=>'0') when others;
   
pattern_scale_down_chip: image_2Nx2N_scale_down
   Generic map(N,6-N)
   Port map( 
      cam_clk,
      pattern_rd_addr, pattern_rd_pixel,
      pattern_wr_addr, pattern_wr_pixel
   );

pattern_learn_RAM: RAM_2NxM_2clk
  GENERIC MAP (2*N,8)
  PORT MAP (
    clka  => cam_clk,
    wea   => (0=>pattern_learn_cwr),
    addra => pattern_wr_addr,
    dina  => pattern_wr_pixel,
    clkb  => cpu_clk,
    addrb => cpu_data_in_addr,
    doutb => pattern_learn_pixel
  );

pattern_forget_RAM: RAM_2NxM_2clk
  GENERIC MAP (2*N,8)
  PORT MAP (
    clka  => cam_clk,
    wea   => (0=>pattern_forget_cwr),
    addra => pattern_wr_addr,
    dina  => pattern_wr_pixel,
    clkb  => cpu_clk,
    addrb => cpu_data_in_addr,
    doutb => pattern_forget_pixel
  );
-----------------------------------------------------
image_down_chip: image_2Nx2N_scale_down
   Generic map(N,8-N)
   Port map( 
      cam_clk,
      cambuffer_rd_addr2, cambuffer_rd_pixel2,
      image_down_wr_addr, image_down_wr_pixel
   );

image_down_RAM : RAM_2NxM_2clk
  GENERIC MAP (2*N,8)
  PORT MAP (
    clka => cam_clk,
    wea => (0=>'1'),
    addra => image_down_wr_addr,
    dina => image_down_wr_pixel,
    clkb => cpu_clk,
    addrb => cpu_data_in_addr,
    doutb => image_pixel
  );
-----------------------------------------------------

process(cpu_clk)
variable fsm: natural range 0 to 7:=0;
variable cnt: natural:=0;
variable key1_latch: std_logic:='0';
begin
   if rising_edge(cpu_clk) then
   if reset_signal='1' then learn_touch<=(others=>'0'); end if;
   case fsm is
   when 0 => patterns_reload<='0'; 
             pattern_forget_cwr<='0'; pattern_learn_cwr<='0';
             key1_latch:='1';
             fsm:=1;
   when 1 => if cpu_trained='1' then
               cpu_data_in_addr<=(others=>'0');
               cpu_reload<='1';
               fsm:=2;
             end if;
   when 2 => if cpu_learn='1' then cpu_data_in<=pattern_learn_pixel;
             elsif cpu_forget='1' then cpu_data_in<=pattern_forget_pixel;
             else cpu_data_in<=image_pixel;
             end if;
             fsm:=3;
   when 3 => if cpu_data_in_addr=(2*N-1 downto 0 => '1')
             then cpu_reload<='0'; fsm:=5;
             else cpu_data_in_addr<=cpu_data_in_addr+1; fsm:=2;
             end if;
   when 5 => if cpu_trained='1' then
                cpu_learn<='0'; cpu_forget<='0';
                cnt:=0;
                fsm:=6;
             end if;
   when 6 => if (key1='1')and(key1_latch='1') then 
                key1_latch:='0';
                patterns_reload<='0';
                pattern_forget_cwr<='1';
                cnt:=0; fsm:=7;
             end if;
             if (key1='0')and(key1_latch='0') then
                key1_latch:='1';
                patterns_reload<='0';
                pattern_learn_cwr<='1';
                cnt:=0; fsm:=7;
             end if;
             if cnt=2**25 then fsm:=1; else cnt:=cnt+1; end if;
   when 7 => if cnt=2**20 then
                if key1_latch='1'
                then pattern_learn_cwr<='0'; patterns_reload<='0'; cpu_learn<='1';
                     learn_touch(conv_integer(pattern_idx))<='1';
                else pattern_forget_cwr<='0'; patterns_reload<='1'; --cpu_forget<='1';
                     if learn_touch(conv_integer(pattern_idx))='1' then cpu_forget<='1'; end if;
                end if;
                fsm:=1;
             else cnt:=cnt+1;
             end if;
   when others => null;
   end case;
   end if;
end process;

cpu: neural_hopfield_cpu
   generic map(2*N)
   port map(
		clk        => cpu_clk,
      reset      => reset_signal,
      reload     => cpu_reload,
      learn      => cpu_learn,
      forget     => cpu_forget,
      data_in_addr => cpu_data_in_addr,
      data_in   => cpu_data_in,
      data_out_addr => cpu_data_out_addr,
      data_out  => cpu_data_out,
      trained    => cpu_trained
	 );

scale_up_chip: image_2Nx2N_scale_up
   Generic map(N,8-N)
   Port map(cpu_clk, cpu_data_out_addr, cpu_data_out,
      buffer_img_out_wr_addr, buffer_img_out_wr_pixel
   );
    
buffer_img_out : RAM_2NxM
   GENERIC MAP (16,8)
   PORT MAP (
      cpu_clk,(0=>'1'),
      buffer_img_out_wr_addr, buffer_img_out_wr_pixel,
      buffer_y(7 downto 0) & buffer_x(7 downto 0), buffer_pixel
   );
end;
