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

entity RAM_2NxM_2in_3out is
    generic (N:natural range 1 to 16:=0; M:natural range 1 to 32:=8);
    port (CLK  : in std_logic;
          WEA  : in std_logic_vector(0 downto 0);
          WEB  : in std_logic_vector(0 downto 0);
          ADDRA: in std_logic_vector(N-1 downto 0);
          DINA : in std_logic_vector(M-1 downto 0);
          ADDRB: in std_logic_vector(N-1 downto 0);
          DINB : in std_logic_vector(M-1 downto 0);
          ADDR1: in std_logic_vector(N-1 downto 0);
          DOUT1: out std_logic_vector(M-1 downto 0);
          ADDR2: in std_logic_vector(N-1 downto 0);
          DOUT2: out std_logic_vector(M-1 downto 0);
          ADDR3: in std_logic_vector(N-1 downto 0);
          DOUT3: out std_logic_vector(M-1 downto 0)
    );
end RAM_2NxM_2in_3out;

architecture XC7A100T of RAM_2NxM_2in_3out is
   type ram_type is array (2**n-1 downto 0) of std_logic_vector(M-1 downto 0);
   signal RAM: ram_type;
begin
    process (CLK)
    begin
        if rising_edge(CLK) then
           if WEA(0) = '1' then RAM(conv_integer(ADDRA)) <= DINA; end if;
           if WEB(0) = '1' then RAM(conv_integer(ADDRB)) <= DINB; end if;
           DOUT1 <= RAM(conv_integer(ADDR1));
           DOUT2 <= RAM(conv_integer(ADDR2));
           DOUT3 <= RAM(conv_integer(ADDR3));
        end if;
    end process;
end;