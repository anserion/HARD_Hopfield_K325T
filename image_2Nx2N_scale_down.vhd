------------------------------------------------------------------
--Copyright 2023 Andrey S. Ionisyan (anserion@gmail.com)
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

----------------------------------------------------------------------------------
-- Engineer: Andrey S. Ionisyan <anserion@gmail.com>
-- 
-- Description: neural network Layer forward step
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use ieee.std_logic_unsigned.all;

entity image_2Nx2N_scale_down is
   Generic (N:natural range 1 to 16:=5;
            K:natural range 1 to 16:=3);
    Port ( 
		clk      : in std_logic;
      addr_in  : out std_logic_vector(2*N+2*K-1 downto 0);
      pixel_in : in std_logic_vector(7 downto 0);
      addr_out : out std_logic_vector(2*N-1 downto 0);
      pixel_out: out std_logic_vector(7 downto 0)
	 );
end image_2Nx2N_scale_down;

architecture XC7A100T of image_2Nx2N_scale_down is
signal addr_out_reg:std_logic_vector(2*N-1 downto 0);
signal addr_in_reg:std_logic_vector(2*N+2*K-1 downto 0);
begin
addr_in<=addr_in_reg;
addr_out<=addr_out_reg;

scale_down_gen: process (clk)
variable fsm:natural range 0 to 7:=0;
variable addr_y0_in: std_logic_vector(2*N+2*K-1 downto 0):=(others=>'0');
variable addr_x0_in: std_logic_vector(N+K-1 downto 0):=(others=>'0');
variable sum:std_logic_vector(4*(N+K)-1 downto 0):=(others=>'0');
variable cnt:std_logic_vector(2*K-1 downto 0):=(others=>'0');
begin
   if rising_edge(clk) then
   case fsm is
   when 0=> --addr_out_reg<=(others=>'0');
            fsm:=1;
   when 1=> addr_y0_in:=addr_out_reg(2*N-1 downto N) & (N+K+K-1 downto 0 => '0');
            addr_x0_in:=addr_out_reg(N-1 downto 0) & (K-1 downto 0 => '0');
            sum:=(others=>'0');
            --cnt:=(others=>'0');
            fsm:=2;
   when 2=> addr_in_reg<=
               addr_y0_in + (cnt(2*K-1 downto K) & (N+K-1 downto 0 => '0')) +
               addr_x0_in + cnt(K-1 downto 0);
            fsm:=3;
   when 3=> sum:=sum+pixel_in;
            cnt:=cnt+1;
            fsm:=4;
   when 4=> if cnt=0 then fsm:=5; else fsm:=2; end if;
   when 5=> pixel_out<=sum(2*K+7 downto 2*K);
            fsm:=6;
   when 6=> addr_out_reg<=addr_out_reg+1;
            fsm:=1;
   when others=> NULL;
   end case;
   end if;
end process;
end;
