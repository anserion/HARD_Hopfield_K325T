------------------------------------------------------------------
--Copyright 2022 Andrey S. Ionisyan (anserion@gmail.com)
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
-- Description: simple RAM entity (BRAM economy)
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use ieee.std_logic_unsigned.all;

entity RAM_16x8 is
    port (CLK  : in std_logic;
          WEA  : in std_logic_vector(0 downto 0);
          ADDRA: in std_logic_vector(3 downto 0);
          DINA : in std_logic_vector(7 downto 0);
          ADDRB: in std_logic_vector(3 downto 0);
          DOUTB: out std_logic_vector(7 downto 0)
    );
end RAM_16x8;

architecture XC7A100T of RAM_16x8 is
   type ram_type is array (15 downto 0) of std_logic_vector(7 downto 0);
   signal RAM: ram_type;
begin
    process (CLK)
    begin
        if rising_edge(clk) then
           if WEA(0) = '1' then RAM(conv_integer(ADDRA)) <= DINA; end if;
            DOUTB <= RAM(conv_integer(ADDRB)) ;
        end if;
    end process;
end;