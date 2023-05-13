------------------------------------------------------------------
--Copyright 2017-2022 Andrey S. Ionisyan (anserion@gmail.com)
--Licensed under the Apache License, Version 2.0 (the "License");
--you may not use this file except in compliance with the License.
--You may obtain a copy of the License at
--    http://www.apache.org/licenses/LICENSE-2.0
--Unless required by applicable law or agreed to in writing, software
--distributed under the License is distributed on an "AS IS" BASIS,
--WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--See the License for the specific language governing permissions and
--limitations under the License.
------------------------------------------------------------------

-- simple LCD controller for TM043NBH02 panel on AN430_LCD device

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity LCD_AN430 is
    Port (lcd_clk   : in std_logic;
          lcd_r_out : out  STD_LOGIC_VECTOR (7 downto 0);
          lcd_g_out : out  STD_LOGIC_VECTOR (7 downto 0);
          lcd_b_out : out  STD_LOGIC_VECTOR (7 downto 0);
          lcd_de    : out  STD_LOGIC;
			 clk_wr: in std_logic;
          x : in  STD_LOGIC_VECTOR (9 downto 0);
          y : in  STD_LOGIC_VECTOR (9 downto 0);
			 pixel : in std_logic_vector(7 downto 0)
    );
end LCD_AN430;

architecture XC7A100T of LCD_AN430 is
COMPONENT RAM_2NxM_2clk is
    generic (N:natural range 1 to 32:=0; M:natural range 1 to 32:=8);
    port (CLKA : in std_logic;
          WEA  : in std_logic_vector(0 downto 0);
          ADDRA: in std_logic_vector(N-1 downto 0);
          DINA : in std_logic_vector(M-1 downto 0);
          CLKB : in std_logic;
          ADDRB: in std_logic_vector(N-1 downto 0);
          DOUTB: out std_logic_vector(M-1 downto 0)
    );
END COMPONENT;

------------------------------------------------------------------
-- timing from TM043NBH02 datasheet
------------------------------------------------------------------
constant H_cycle: natural:= 525;
constant Hde_start: natural:=43;
constant H_display_period: natural:=480;
constant Hde_end: natural:=523;

constant V_cycle: natural:=286;
constant Vde_start: natural:=12;
constant V_display_period: natural:=272;
constant Vde_end: natural:=284;
------------------------------------------------------------------
signal de_reg: std_logic:='0';
signal H_de, V_de, H_start, V_start: std_logic;
signal addr_reg: natural range 0 to H_display_period*V_display_period;
signal x_cnt: natural range 0 to H_cycle;
signal y_cnt: natural range 0 to V_cycle;

signal mem_addr: std_logic_vector(17 downto 0);
signal pixel_gray_out:std_logic_vector(7 downto 0);
begin
mem_addr<=(y&"00000000")
			+(y&"0000000")
			+(y&"000000")
			+(y&"00000")
			+("00000000"&x);
lcd_vram: RAM_2NxM_2clk 
  GENERIC MAP (17,8)
  PORT MAP (
    clka => clk_wr,
    wea => (0=>'1'),
    addra => mem_addr(16 downto 0),
    dina => pixel,
    clkb => lcd_clk,
    addrb => conv_std_logic_vector(addr_reg,17),
    doutb => pixel_gray_out
  );
--data enable
de_reg<=H_de and V_de;
lcd_de<=de_reg;
--write data to lcd from RGB registers
lcd_r_out<=pixel_gray_out when de_reg='1' else "00000000";
lcd_g_out<=pixel_gray_out when de_reg='1' else "00000000";
lcd_b_out<=pixel_gray_out when de_reg='1' else "00000000";

------------------------------------------------------------------
-- lcd controller
------------------------------------------------------------------
process (lcd_clk)
begin
   if rising_edge(lcd_clk) then
      if x_cnt=H_cycle then x_cnt<=0; y_cnt<=y_cnt+1; else x_cnt<=x_cnt+1; end if;
      if y_cnt=V_cycle then y_cnt<=0; end if;
      
      if x_cnt=Hde_start then H_de<='1'; H_start<='1'; else H_start<='0'; end if;
      if x_cnt=Hde_end then H_de<='0'; end if;
      
      if y_cnt=Vde_start then V_de<='1'; V_start<='1'; else V_start<='0'; end if;
      if y_cnt=Vde_end then V_de<='0'; end if;
     
      if de_reg='1' then addr_reg<=addr_reg+1; end if;
      if H_start='1' and V_start='1' then addr_reg<=0; end if;
   end if;
end process;
end;
