------------------------------------------------------------------
--Copyright 2019-2022 Andrey S. Ionisyan (anserion@gmail.com)
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
-- Description: keys supervisor.
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity keys_supervisor is
   Port ( 
      clk : in std_logic;
      key : in std_logic_vector(1 downto 0);
      key0: out std_logic;
      key1: out std_logic;
      reset_signal: out std_logic;
      value  : out std_logic_vector(2 downto 0)
	);
end keys_supervisor;

architecture XC7A100T of keys_supervisor is
   signal key0_reg: std_logic:='0';
   signal key1_reg: std_logic:='0';
   signal reset_reg: std_logic:='0';
   signal value_reg: std_logic_vector(2 downto 0):=conv_std_logic_vector(0,3);
begin
   key0<=key0_reg;
   key1<=key1_reg;
   reset_signal<=reset_reg;
   value<=value_reg;
   
   process(clk)
   variable fsm: natural range 0 to 7 := 0;
   variable debounce_cnt: natural range 0 to 1023:=0;
   variable timer_cnt: natural:=0;
   begin
      if rising_edge(clk) then
         case fsm is
         -- wait for press any control key
         when 0 =>
            reset_reg<='0';
            key0_reg<='0';
            key1_reg<='0';
            if (key(0)='0')or(key(1)='0')
            then debounce_cnt:=0; fsm:=1;
            end if;
         -- debounce
         when 1 =>
            if debounce_cnt=500 then fsm:=2;
            else debounce_cnt:=debounce_cnt+1;
            end if;
         -- change registers
         when 2 =>
            if (key(0)='0') then key0_reg<='1'; value_reg<=value_reg+1; end if;
            if (key(1)='0') then key1_reg<='1'; end if;
            timer_cnt:=0;
            fsm:=3;
         -- wait for release all control keys
         when 3 =>
            if (key(0)='0')and(timer_cnt=20000) then reset_reg<='1'; end if;
            if (key(0)='1')and(key(1)='1') then debounce_cnt:=0; fsm:=4;
            else timer_cnt:=timer_cnt+1;
            end if;
         -- debounce
         when 4 =>
            if debounce_cnt=500 then fsm:=0;
            else debounce_cnt:=debounce_cnt+1;
            end if;
         when others => null;
         end case;
      end if;
   end process;
end;
