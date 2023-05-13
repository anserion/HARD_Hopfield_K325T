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

----------------------------------------------------------------------------------
-- Engineer: Andrey S. Ionisyan <anserion@gmail.com>
-- 
-- Description: Captures pixels from OV7670 640x480 camera 16bpp out
--              convert to 480x272x8bpp RAM
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity CAM_OV7670 is
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
end CAM_OV7670;

architecture XC7A100T of CAM_OV7670 is
signal pixel_reg: std_logic_vector(15 downto 0);
signal ready_reg:std_logic;
signal x_reg,y_reg: std_logic_vector(9 downto 0);
begin
pixel<=pixel_reg(7 downto 0);
ready<=ready_reg;
x<=x_reg;
y<=y_reg;

process(clk)
   variable FSM: std_logic:='0';
   variable byte1 : std_logic_vector(7 downto 0):= (others => '0');
begin
   if rising_edge(clk) then
      if vsync='1' then
         x_reg<=(others=>'0'); y_reg<=(others=>'0');
         ready_reg<='0'; FSM:='0';
      end if;
      if href='0' then x_reg<=(others=>'0'); ready_reg<='0'; FSM:='0'; end if;
      if (vsync='0') and (href='1') then
         if FSM='0' then ready_reg<='0'; byte1:=din;
         else
            pixel_reg<=byte1 & din;
            if x_reg=0 then y_reg<=y_reg+1; end if;
            x_reg<=x_reg+1;
            ready_reg<='1';
         end if;
         FSM:=not(FSM);
      end if;
   end if;
end process;
end;
